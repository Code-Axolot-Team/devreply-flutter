package com.devreply.flutter

import android.app.Activity
import android.content.Context
import androidx.compose.runtime.snapshotFlow
import com.devreply.sdk.DevReply
import com.devreply.sdk.DevReplyCategory
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.launch

/** The Flutter bridge: every call goes to the native DevReply SDK. Flutter calls in on the main thread. */
class DevReplyPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware, EventChannel.StreamHandler {
  private lateinit var channel: MethodChannel
  private lateinit var events: EventChannel
  private lateinit var chatEvents: EventChannel
  private var eventSink: EventChannel.EventSink? = null
  private var eventSubscription: com.devreply.sdk.DevReplySubscription? = null
  private lateinit var context: Context
  private var activity: Activity? = null
  private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
  private var sink: EventChannel.EventSink? = null
  private var watching: Job? = null
  private var configured = false
  /** A DevReply link that opened the app before Dart called configure. */
  private var pendingLink: android.net.Uri? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, "devreply").also { it.setMethodCallHandler(this) }
    events = EventChannel(binding.binaryMessenger, "devreply/unread").also { it.setStreamHandler(this) }
    // What happens in the chat, for the app's analytics.
    chatEvents = EventChannel(binding.binaryMessenger, "devreply/events").also {
      it.setStreamHandler(object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
          eventSink = sink
          if (eventSubscription == null) eventSubscription = DevReply.addEventListener { e -> eventSink?.success(eventMap(e)) }
        }
        override fun onCancel(arguments: Any?) {
          eventSink = null
        }
      })
    }
  }

  private fun eventMap(e: com.devreply.sdk.DevReplyEvent): Map<String, Any?> = when (e) {
    is com.devreply.sdk.DevReplyEvent.MessengerOpened -> mapOf("type" to "messengerOpened")
    is com.devreply.sdk.DevReplyEvent.MessengerClosed -> mapOf("type" to "messengerClosed")
    is com.devreply.sdk.DevReplyEvent.ConversationStarted ->
      mapOf("type" to "conversationStarted", "conversationId" to e.conversationId, "category" to e.category?.name?.lowercase())
    is com.devreply.sdk.DevReplyEvent.MessageSent -> mapOf("type" to "messageSent", "conversationId" to e.conversationId)
  }

  private fun theme(colors: Map<String, String>?, base: com.devreply.sdk.DevReplyTheme): com.devreply.sdk.DevReplyTheme {
    fun c(key: String): androidx.compose.ui.graphics.Color? = colors?.get(key)?.let(::parseHex)
    return base.copy(
      primary = c("primary") ?: base.primary,
      accent = c("accent") ?: base.accent,
      userBubble = c("userBubble") ?: base.userBubble,
      userBubbleText = c("userBubbleText") ?: base.userBubbleText,
      background = c("background") ?: base.background,
      ink = c("ink") ?: base.ink,
    )
  }

  /** `#RRGGBBAA` (from Dart) or `#RRGGBB`. */
  private fun parseHex(hex: String): androidx.compose.ui.graphics.Color? {
    val clean = hex.trim().removePrefix("#")
    val v = clean.toLongOrNull(16) ?: return null
    return when (clean.length) {
      6 -> androidx.compose.ui.graphics.Color(0xFF000000 or v)
      8 -> androidx.compose.ui.graphics.Color(((v and 0xFF) shl 24) or (v ushr 8))
      else -> null
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    events.setStreamHandler(null)
    chatEvents.setStreamHandler(null)
    eventSubscription?.cancel()
    scope.cancel()
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "configure" -> {
        val key = call.argument<String>("key") ?: return result.error("key", "a public key is required", null)
        // The current screen if there is one: the unread bubble then shows on it straight away.
        DevReply.configure(activity ?: context, key)
        configured = true
        watchUnread()
        pendingLink?.let { DevReply.handle(activity ?: context, it) }
        pendingLink = null
        result.success(null)
      }
      "present" -> {
        val category = call.argument<String>("category")
        val attributes = call.argument<Map<String, Any>>("attributes") ?: emptyMap()
        result.success(
          DevReply.present(
            activity ?: context,
            DevReplyCategory.entries.firstOrNull { it.name.equals(category, ignoreCase = true) },
            call.argument<String>("message"),
            attributes,
            call.argument<Boolean>("askName") ?: true,
          ),
        )
      }
      "isAvailable" -> result.success(DevReply.isAvailable)
      "setTheme" -> {
        when (call.argument<String>("lightMode")) {
          "reset" -> DevReply.theme = com.devreply.sdk.DevReplyTheme()
          "custom" -> DevReply.theme = theme(call.argument("light"), com.devreply.sdk.DevReplyTheme())
        }
        when (call.argument<String>("darkMode")) {
          "off" -> DevReply.darkTheme = null
          "default" -> DevReply.darkTheme = com.devreply.sdk.DevReplyTheme.Dark
          "custom" -> DevReply.darkTheme = theme(call.argument("dark"), com.devreply.sdk.DevReplyTheme.Dark)
        }
        result.success(null)
      }
      "login" -> {
        call.argument<String>("userId")?.let { DevReply.login(it) }
        result.success(null)
      }
      "logout" -> {
        DevReply.logout()
        result.success(null)
      }
      "deleteUser" -> DevReply.deleteUser { ok -> result.success(ok) }
      "setUser" -> {
        DevReply.setUser(call.argument<String>("name"), call.argument<String>("email"))
        result.success(null)
      }
      "setAttributes" -> {
        DevReply.setAttributes(call.argument<Map<String, Any?>>("attributes") ?: emptyMap())
        result.success(null)
      }
      "unreadCount" -> result.success(DevReply.unreadCount)
      "setShowsUnreadBubble" -> {
        DevReply.showsUnreadBubble = call.argument<Boolean>("shows") ?: true
        result.success(null)
      }
      "setLocale" -> {
        DevReply.setLocale(call.argument<String>("tag"))
        result.success(null)
      }
      "handle" -> {
        val url = call.argument<String>("url")
        result.success(url != null && openLink(android.net.Uri.parse(url)))
      }
      "registerPushToken" -> {
        call.argument<String>("token")?.let { DevReply.registerPush(context, it) }
        result.success(null)
      }
      "handleNotificationOpened" -> {
        val data = call.argument<Map<String, String>>("data") ?: emptyMap()
        result.success(DevReply.handleNotificationOpened(activity ?: context, data))
      }
      "handlePush" -> {
        val data = call.argument<Map<String, String>>("data") ?: emptyMap()
        result.success(DevReply.handlePush(context, data))
      }
      else -> result.notImplemented()
    }
  }

  // Unread count stream: the current value, then every change (it's Compose state in the SDK).
  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    sink = events
    events?.success(DevReply.unreadCount)
  }

  override fun onCancel(arguments: Any?) {
    sink = null
  }

  private fun watchUnread() {
    if (watching != null) return
    watching = scope.launch {
      snapshotFlow { DevReply.unreadCount }.distinctUntilChanged().collect { sink?.success(it) }
    }
  }

  /** The button in DevReply's emails opens the app with `…?devreply=<conversation id>`: open it. */
  private fun openLink(uri: android.net.Uri?): Boolean {
    val id = uri?.takeIf { it.isHierarchical }?.getQueryParameter("devreply") ?: return false
    if (!Regex("^[0-9a-fA-F-]{36}$").matches(id)) return false
    if (configured) DevReply.handle(activity ?: context, uri) else pendingLink = uri
    return true
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    openLink(binding.activity.intent?.data)
    binding.addOnNewIntentListener { intent -> openLink(intent.data) }
  }
  override fun onDetachedFromActivityForConfigChanges() { activity = null }
  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
  override fun onDetachedFromActivity() { activity = null }
}
