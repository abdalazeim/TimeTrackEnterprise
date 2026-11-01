import 'package:go_router/go_router.dart';

import 'presentation/pages/goods_page.dart';
import 'presentation/pages/receiving_page.dart';
import 'presentation/pages/reports_page.dart';
import 'presentation/pages/shipment_detail_page.dart';
import 'presentation/pages/shipment_form_page.dart';
import 'presentation/pages/shipments_page.dart';
import 'presentation/pages/trip_detail_page.dart';
import 'presentation/pages/trip_form_page.dart';
import 'presentation/pages/trips_page.dart';
import 'transport_routes.dart';

/// Route definitions for projects that opt into the transport sample.
class TransportExampleRoutes {
  const TransportExampleRoutes._();

  static List<RouteBase> get routes => <RouteBase>[
        GoRoute(
          path: TransportRoutes.shipments,
          builder: (context, state) => const ShipmentsPage(),
        ),
        GoRoute(
          path: TransportRoutes.shipmentNew,
          builder: (context, state) => const ShipmentFormPage(),
        ),
        GoRoute(
          path: '${TransportRoutes.shipments}/:id',
          builder: (context, state) => ShipmentDetailPage(
            shipmentId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '${TransportRoutes.shipments}/:id/edit',
          builder: (context, state) => ShipmentEditLoader(
            shipmentId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: TransportRoutes.receiving,
          builder: (context, state) => const ReceivingPage(),
        ),
        GoRoute(
          path: TransportRoutes.goods,
          builder: (context, state) => const GoodsPage(),
        ),
        GoRoute(
          path: TransportRoutes.trips,
          builder: (context, state) => const TripsPage(),
        ),
        GoRoute(
          path: TransportRoutes.tripNew,
          builder: (context, state) => const TripFormPage(),
        ),
        GoRoute(
          path: '${TransportRoutes.trips}/:id',
          builder: (context, state) => TripDetailPage(
            tripId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '${TransportRoutes.trips}/:id/edit',
          builder: (context, state) => TripEditLoader(
            tripId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: TransportRoutes.reports,
          builder: (context, state) => const ReportsPage(),
        ),
      ];
}
