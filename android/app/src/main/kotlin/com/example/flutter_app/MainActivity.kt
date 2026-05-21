package com.example.flutter_app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val methodChannelName = "com.cameyo.app/speech"
    private val eventChannelName = "com.cameyo.app/speech_events"
    private val recordAudioRequestCode = 1001

    private var recognizer: SpeechRecognizer? = null
    private var eventSink: EventChannel.EventSink? = null
    private var pendingStartResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
                            == PackageManager.PERMISSION_GRANTED
                        ) {
                            startRecognizer()
                            result.success(null)
                        } else {
                            pendingStartResult = result
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.RECORD_AUDIO),
                                recordAudioRequestCode,
                            )
                        }
                    }
                    "stop" -> {
                        recognizer?.stopListening()
                        result.success(null)
                    }
                    "cancel" -> {
                        recognizer?.cancel()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == recordAudioRequestCode) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                startRecognizer()
                pendingStartResult?.success(null)
            } else {
                pendingStartResult?.error("PERMISSION_DENIED", "Permiso de micrófono denegado", null)
            }
            pendingStartResult = null
        }
    }

    private fun startRecognizer() {
        recognizer?.destroy()
        recognizer = SpeechRecognizer.createSpeechRecognizer(this)
        recognizer?.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                eventSink?.success(mapOf("type" to "status", "value" to "listening"))
            }
            override fun onBeginningOfSpeech() {
                // No action needed: speech start is tracked via onReadyForSpeech status event
            }
            override fun onRmsChanged(rmsdB: Float) {
                // No action needed: RMS audio level changes are not exposed to the Flutter layer
            }
            override fun onBufferReceived(buffer: ByteArray?) {
                // No action needed: raw audio buffer processing is handled by the SpeechRecognizer
            }
            override fun onEndOfSpeech() {
                eventSink?.success(mapOf("type" to "status", "value" to "processing"))
            }
            override fun onError(error: Int) {
                eventSink?.success(mapOf("type" to "error", "value" to error))
            }
            override fun onResults(results: Bundle?) {
                val text = results
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull() ?: ""
                eventSink?.success(mapOf("type" to "result", "value" to text))
            }
            override fun onPartialResults(partialResults: Bundle?) {
                val text = partialResults
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull() ?: ""
                if (text.isNotEmpty()) {
                    eventSink?.success(mapOf("type" to "partial", "value" to text))
                }
            }
            override fun onEvent(eventType: Int, params: Bundle?) {
                // No action needed: reserved Android callback with no defined semantic for this use case
            }
        })

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "es-ES")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }
        recognizer?.startListening(intent)
    }

    override fun onDestroy() {
        recognizer?.destroy()
        super.onDestroy()
    }
}
