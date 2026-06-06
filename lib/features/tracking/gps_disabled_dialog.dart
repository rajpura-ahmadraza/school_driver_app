import 'dart:async';



import 'package:easy_localization/easy_localization.dart';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:geolocator/geolocator.dart';

import '../../core/router/app_router.dart';

import '../../core/theme/app_theme.dart';

import '../../core/widgets/premium_dialog.dart';



const _gpsChannel = MethodChannel('com.example.school_driver_app/gps');



Future<void> _enableGpsAutomatically() async {

  try {

    final bool success =

        await _gpsChannel.invokeMethod<bool>('enableGps') ?? false;

    if (!success) {

      await Geolocator.openLocationSettings();

    }

  } on PlatformException {

    await Geolocator.openLocationSettings();

  }

}



/// Premium GPS-off dialog (Cancel + Enable). Shown when user taps Start Tracking.

Future<void> showGpsDisabledDialog(BuildContext context) {

  return showDialog<void>(

    context: context,

    useRootNavigator: true,

    barrierDismissible: false,

    builder: (_) => const _GpsDisabledDialog(),

  );

}



class _GpsDisabledDialog extends StatefulWidget {

  const _GpsDisabledDialog();



  @override

  State<_GpsDisabledDialog> createState() => _GpsDisabledDialogState();

}



class _GpsDisabledDialogState extends State<_GpsDisabledDialog>

    with WidgetsBindingObserver {

  StreamSubscription<ServiceStatus>? _gpsStatusSubscription;

  bool _dismissed = false;

  bool _checking = false;



  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _gpsStatusSubscription =

        Geolocator.getServiceStatusStream().listen((status) {

      if (status == ServiceStatus.enabled) {

        _closeIfEnabled();

      }

    });

  }



  @override

  void dispose() {

    WidgetsBinding.instance.removeObserver(this);

    _gpsStatusSubscription?.cancel();

    super.dispose();

  }



  @override

  void didChangeAppLifecycleState(AppLifecycleState state) {

    if (state == AppLifecycleState.resumed) {

      _closeIfEnabled();

    }

  }



  /// Pops only this dialog once — avoids double-pop blank screen after Enable.

  void _dismissDialog() {

    if (_dismissed) return;

    _dismissed = true;



    final navigator = rootNavigatorKey.currentState;

    if (navigator != null && navigator.canPop()) {

      navigator.pop();

    }

  }



  Future<void> _closeIfEnabled() async {

    if (_dismissed || _checking || !mounted) return;

    _checking = true;

    try {

      final enabled = await Geolocator.isLocationServiceEnabled();

      if (enabled && mounted) {

        _dismissDialog();

      }

    } finally {

      _checking = false;

    }

  }



  Future<void> _onEnablePressed() async {

    await _enableGpsAutomatically();

    await Future<void>.delayed(const Duration(milliseconds: 400));

    if (mounted) await _closeIfEnabled();

  }



  @override

  Widget build(BuildContext context) {

    return PopScope(

      canPop: false,

      child: PremiumDialogFrame(

        child: PremiumDialogBody(

          icon: Icons.location_off_rounded,

          iconColor: AppTheme.danger,

          title: 'gps_dialog_title'.tr(),

          message: 'gps_dialog_desc'.tr(),

          actions: Row(

            children: [

              Expanded(

                child: PremiumDialogOutlinedButton(

                  label: 'cancel'.tr(),

                  onPressed: _dismissDialog,

                ),

              ),

              const SizedBox(width: 12),

              Expanded(

                child: PremiumDialogFilledButton(

                  label: 'enable'.tr(),

                  color: AppTheme.primary,

                  onPressed: _onEnablePressed,

                ),

              ),

            ],

          ),

        ),

      ),

    );

  }

}


