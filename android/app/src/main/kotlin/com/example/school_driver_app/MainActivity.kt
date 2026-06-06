package com.example.school_driver_app

import android.app.Activity
import android.content.Intent
import android.content.IntentSender

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

import com.google.android.gms.common.api.ResolvableApiException
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.LocationSettingsRequest
import com.google.android.gms.location.LocationSettingsResponse
import com.google.android.gms.location.Priority
import com.google.android.gms.location.SettingsClient
import com.google.android.gms.tasks.Task

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.school_driver_app/gps"
    private var pendingResult: MethodChannel.Result? = null

    companion object {
        private const val REQUEST_CHECK_SETTINGS = 1001
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            if (call.method == "enableGps") {
                pendingResult = result
                enableGpsAuto()
            } else {
                result.notImplemented()
            }
        }
    }

    private fun enableGpsAuto() {

        val locationRequest =
            LocationRequest.Builder(
                Priority.PRIORITY_HIGH_ACCURACY,
                10000
            ).build()

        val settingsRequest =
            LocationSettingsRequest.Builder()
                .addLocationRequest(locationRequest)
                .build()

        val client: SettingsClient =
            LocationServices.getSettingsClient(this)

        val task: Task<LocationSettingsResponse> =
            client.checkLocationSettings(settingsRequest)

        task.addOnSuccessListener {
            pendingResult?.success(true)
            pendingResult = null
        }

        task.addOnFailureListener { e ->

            if (e is ResolvableApiException) {

                try {
                    e.startResolutionForResult(
                        this,
                        REQUEST_CHECK_SETTINGS
                    )

                } catch (_: IntentSender.SendIntentException) {

                    pendingResult?.success(false)
                    pendingResult = null
                }

            } else {

                pendingResult?.success(false)
                pendingResult = null
            }
        }
    }

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?
    ) {

        super.onActivityResult(
            requestCode,
            resultCode,
            data
        )

        if (requestCode == REQUEST_CHECK_SETTINGS) {

            pendingResult?.success(
                resultCode == Activity.RESULT_OK
            )

            pendingResult = null
        }
    }
}