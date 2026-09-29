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
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    events.setStreamHandler(null)
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
        DevReply.present(activity ?: context, DevReplyCategory.entries.firstOrNull { it.name.equals(category, ignoreCase = true) })
        result.success(null)
      }
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
      // Android push comes with FCM support in the SDK.
      "registerPushToken" -> result.success(null)
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
