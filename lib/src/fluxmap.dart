import 'dart:async';

import 'package:device/device.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:fluxmap/src/state.dart';
import 'package:fluxmap/src/types.dart';
import 'package:latlong/latlong.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';

import 'store.dart';

class _FluxMapWidgetState extends State<_FluxMapWidget> {
  _FluxMapWidgetState(
      {
        @required this.devicesFlux,
        this.center,
        this.zoom = 2.0,
        this.networkStatusLoop = true,
        this.onTap,
        this.onPositionChanged,
        this.extraLayers = const <LayerOptions>[]})
      : assert(devicesFlux != null) {
    center ??= LatLng(0.0, 0.0);
  }

  final Stream<Device> devicesFlux;
  LatLng center;
  final double zoom;
  final bool networkStatusLoop;
  final TapCallback onTap;
  final PositionCallback onPositionChanged;
  final List<LayerOptions> extraLayers;

  StreamSubscription<Device> _sub;
  StreamSubscription<MapPosition> _ms;

  bool _updateLoopStarted = false;
  Timer t;
  final _saveMapStateSignal = PublishSubject<MapPosition>();

  Future<void> _listenToFlux() async => _sub = devicesFlux.listen((device) {
    updateFluxMapState(
        type: FluxMapUpdateType.devicePosition, value: device);
  });

  Future<void> _startDeviceLoop() async {
    if (!_updateLoopStarted) {
      t = Timer.periodic(
          const Duration(seconds: 3),
              (t) => updateFluxMapState(
              type: FluxMapUpdateType.devicesStatus, value: null));
      _updateLoopStarted = true;
    }
  }

  @override
  void initState() {
    super.initState();
    //print("MAP STATE ${fluxMapState.map}");
    fluxMapState.map.onReady.then((_) {
      _ms = _saveMapStateSignal
          .debounceTime(const Duration(milliseconds: 200))
          .listen((ms) {
        fluxMapState.center = ms.center;
        fluxMapState.zoom = ms.zoom;
      });
      //print("MAP STATE READY");
      _listenToFlux();
      //print("Status loop: $networkStatusLoop");
      if (networkStatusLoop) {
        _startDeviceLoop();
      }
      /*fluxMapState.map.changeFeed.listen((change) {
        if (change.name != "currentPosition") {
          print("FMAP CHANGE $change");
          if (change.type == MapControllerChangeType.markers) {
            print("Markers change");
          }
        }
      });*/
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<FluxMapStore>(context).state;
    //print("MAP ${state.map} / ${state.map.center}");
    return FlutterMap(
      mapController: state.map.mapController,
      options: MapOptions(
        center: state?.center ?? center,
        zoom: state?.zoom ?? zoom,
        onTap: onTap,
        onPositionChanged: onPositionChanged,
        /*
          onPositionChanged: (position, hasGesture) {
            //print("POS CHANGE $position / $hasGesture");
            //print("BOUNDS: ${state.map.center}/${state.map.zoom}");
            _saveMapStateSignal.sink
                .add(MapPosition(center: position.center, zoom: position.zoom, hasGesture: hasGesture));
          }*/
      ),
      layers: [
        state.map.tileLayer,
        PolygonLayerOptions(polygons: state.map.polygons),
        PolylineLayerOptions(polylines: state.map.lines),
        MarkerLayerOptions(markers: state.map.markers),
        ...extraLayers
      ],
    );
  }

  @override
  void dispose() {
    _sub.cancel();
    _ms.cancel();
    if (_updateLoopStarted) {
      t.cancel();
    }
    super.dispose();
  }
}

class _FluxMapWidget extends StatefulWidget {
  const _FluxMapWidget(
      {@required this.devicesFlux,
        this.networkStatusLoop,
        this.center,
        this.zoom,
        this.onTap,
        this.onPositionChanged,
        this.extraLayers});

  final Stream<Device> devicesFlux;
  final LatLng center;
  final double zoom;
  final bool networkStatusLoop;
  final TapCallback onTap;
  final PositionCallback onPositionChanged;
  final List<LayerOptions> extraLayers;

  @override
  _FluxMapWidgetState createState() => _FluxMapWidgetState(
      devicesFlux: devicesFlux,
      networkStatusLoop: networkStatusLoop,
      center: center,
      zoom: zoom,
      onTap: onTap,
      onPositionChanged: onPositionChanged,
      extraLayers: extraLayers);
}

/// The main fluxmap class
class FluxMap extends StatefulWidget {
  /// Default contructor
  const FluxMap(
      {@required this.devicesFlux,
        @required this.state,
        this.networkStatusLoop = true,
        this.center,
        this.zoom = 2.0,
        this.onTap,
        this.onPositionChanged,
        this.extraLayers = const <LayerOptions>[]});

  /// The stream of device positions updates
  final Stream<Device> devicesFlux;

  /// The state of the map
  final FluxMapState state;

  /// The initial center
  final LatLng center;

  /// The initial zoom
  final double zoom;

  /// Enable the status loop
  final bool networkStatusLoop;

  /// The initial onTap
  final TapCallback onTap;

  /// The initial onPositionChanged
  final PositionCallback onPositionChanged;

  /// Extra map layers
  final List<LayerOptions> extraLayers;

  @override
  _FluxMapState createState() => _FluxMapState(
      devicesFlux: devicesFlux,
      networkStatusLoop: networkStatusLoop,
      state: state,
      center: center,
      zoom: zoom,
      onTap: onTap,
      onPositionChanged: onPositionChanged,
      extraLayers: extraLayers);
}

class _FluxMapState extends State<FluxMap> {
  _FluxMapState(
      {@required this.devicesFlux,
        @required this.state,
        this.networkStatusLoop,
        this.center,
        this.zoom,
        this.onTap,
        this.onPositionChanged,
        this.extraLayers = const <LayerOptions>[]})
      : assert(state != null),
        assert(devicesFlux != null) {
    fluxMapState = state;
  }

  final Stream<Device> devicesFlux;
  final FluxMapState state;
  final LatLng center;
  final double zoom;
  final TapCallback onTap;
  final PositionCallback onPositionChanged;
  final bool networkStatusLoop;
  final List<LayerOptions> extraLayers;

  @override
  Widget build(BuildContext context) {
    return StreamProvider<FluxMapStore>.value(
        initialData: FluxMapStore(),
        value: fluxMapStoreController.stream,
        child: _FluxMapWidget(
          devicesFlux: devicesFlux,
          networkStatusLoop: networkStatusLoop,
          center: center,
          zoom: zoom,
          onTap: onTap,
          onPositionChanged: onPositionChanged,
          extraLayers: extraLayers,
        ));
  }
}