import 'package:device/device.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:map_controller/map_controller.dart';
import 'package:rxdart/rxdart.dart';

import 'default_marker_builder.dart';
import 'defaults_settings.dart';
import 'types.dart';

class FluxMapState {
  FluxMapState(
      {this.map,
      this.markerBuilder,
      this.markerGestureDetectorBuilder,
      this.onDeviceDisconnect,
      this.onDeviceOffline,
      this.onDeviceBackOnline}) {
    map ??= StatefulMapController(mapController: MapController());
    _markersRebuildSignal
        .debounceTime(const Duration(milliseconds: 200))
        .listen((_) {
      _rebuildMarkers();
    });
  }

  StatefulMapController map;
  MarkerGestureDetectorBuilder markerGestureDetectorBuilder;
  FluxMarkerBuilder markerBuilder;
  DeviceNetworkStatusChangeCallback onDeviceDisconnect;
  DeviceNetworkStatusChangeCallback onDeviceOffline;
  DeviceNetworkStatusChangeCallback onDeviceBackOnline;

  final Map<int, Device> _devices = <int, Device>{};
  bool firstPositionUpdateDone = false;
  final _firstPositionUpdateForDevices = <int>[];
  final _markersRebuildSignal = PublishSubject<bool>();

  Map<int, Device> get devices => _devices;

  // **********************************
  // Status loop
  // **********************************

  void checkDevicesStatus() {
    /// rebuild markers if a device status has changed
    for (final device in _devices.values) {
      final current = device.networkStatus;
      final last =
          device.properties["last_network_status"] as DeviceNetworkStatus;
      //print(
      //    "${_devices.length} Device ${device.id} / $dns / ${device.networkStatus}");
      switch (last == current) {
        case false:
          // watch state changes for callbacks to trigger
          if (onDeviceDisconnect != null) {
            if (current == DeviceNetworkStatus.disconnected) {
              onDeviceDisconnect(device);
            }
          }
          if (onDeviceOffline != null) {
            if (current == DeviceNetworkStatus.offline) {
              onDeviceOffline(device);
            }
          }
          if (onDeviceBackOnline != null) {
            if ((last == DeviceNetworkStatus.disconnected ||
                    last == DeviceNetworkStatus.offline) &&
                current == DeviceNetworkStatus.online) {
              onDeviceBackOnline(device);
            }
          }
          // update old status
          device.properties["last_network_status"] = current;
          // refresh markers
          _markersRebuildSignal.sink.add(true);
          return;
          break;
        default:
      }
    }
  }

  // **********************************
  // Position
  // **********************************

  Future<void> updateDevicePosition(Device _device,
      {SpeedUnit speedUnit = SpeedUnit.kilometersPerHour,
      bool verbose = false}) async {
    assert(_device.id != null);
    if (verbose) {
      print("Position update for device:");
      _device.describe();
    }
    if (speedUnit == SpeedUnit.knots) {
      // convert from knots
      _device.position.speed = _device.speed * 1.852;
    }
    // skip invalid point
    if ((_device.position?.speed ?? 0) > maxReasonableSpeed) {
      return;
    }
    // check if the device object is known
    Device device;
    if (_devices.containsKey(_device.id)) {
      device = _devices[_device.id]
        ..position = _device.position
        ..batteryLevel = _device.batteryLevel;
    } else {
      device = _device
        //..sleepingTimeout = defaultSleepingTimeout
        //..keepAlive = defaultKeepAlive
        ..properties["last_network_status"] = _device.networkStatus;
      _devices[device.id] = device;
    }
    _markersRebuildSignal.sink.add(true);
    // init stoff
    if (!_firstPositionUpdateForDevices.contains(device.id)) {
      /*if (tracedDevices.contains(device.id)) {
        setTraceDevice(device, true);
      }*/
      _firstPositionUpdateForDevices.add(device.id);
    }
    // fit markers on map if first launch
    if (!firstPositionUpdateDone) {
      if (_firstPositionUpdateForDevices.length == _devices.length) {
        //unawaited(map.fitMarkers());
        firstPositionUpdateDone = true;
      }
    }
  }

  void _rebuildMarkers() {
    final m = <String, Marker>{};
    _devices.forEach((id, d) {
      if (markerBuilder == null) {
        m["$id"] = defaultMarkerBuilder(d, markerGestureDetectorBuilder);
      } else {
        m["$id"] = markerBuilder(d);
      }
    });
    map.addMarkers(markers: m);
  }

  // **********************************
  // Internal methods
  // **********************************
/*
  void _addAliveDevice(int deviceId) {
    final ad = aliveDevices;
    if (!ad.contains(deviceId)) {
      ad.add(deviceId);
    }
    aliveDevices = ad;
  }

  void _addVisibleDevice(int deviceId) {
    final vd = visibleDevices;
    if (!vd.contains(deviceId)) {
      vd.add(deviceId);
    }
    visibleDevices = vd;
  }

  void _addSleepingDevice(int deviceId) {
    final sd = sleepingDevices;
    if (!sd.contains(deviceId)) {
      sd.add(deviceId);
    }
    sleepingDevices = sd;
  }*/

  void dispose() => _markersRebuildSignal.close();
}