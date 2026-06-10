package com.talk2text.talk2text_mobile

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Bridges Android's PROCESS_TEXT selection action to Flutter: exposes the
/// highlighted text and lets Dart return an edited result to the source app.
class MainActivity : FlutterActivity() {
    private val channelName = "talk2text/process_text"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialProcessText" -> {
                        val text = if (intent?.action == Intent.ACTION_PROCESS_TEXT) {
                            intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)
                                ?.toString()
                        } else {
                            null
                        }
                        result.success(text)
                    }
                    "finishWithText" -> {
                        val text = call.argument<String>("text")
                        val data = Intent().apply {
                            putExtra(Intent.EXTRA_PROCESS_TEXT, text)
                        }
                        setResult(Activity.RESULT_OK, data)
                        result.success(true)
                        finish()
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
