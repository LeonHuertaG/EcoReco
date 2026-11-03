
const express = require('express');

const { authorize } = require('../middleware/session');

const service = require('../services/chofer');
const caja = require('../services/chofer-caja');

const {
  date,
  text,
  imageType,
} = require('../services/chofer-domain');

const router = express.Router();

const withUser = handler => (req, res, next) => {
  Promise.resolve()
    .then(() => handler(req.user.pk_usuario, req, res))
    .then(result => {
      if (
        result !== undefined &&
        !res.headersSent
      ) {
        res.json(result);
      }
    })
    .catch(next);
};

const day = req => date(
  req.query.fecha ?? service.today()
);

const optionalDay = req => req.query.fecha == null ? null : date(req.query.fecha);

const stop = req => req.params.id;

// ========================================
// ADMINISTRADOR: REVISIÓN DE CORTES
// ========================================

router.get(
  '/revision/cortes',
  authorize(1),
  withUser((user, req) =>
    caja.listCuts(optionalDay(req))
  )
);

router.post(
  '/revision/cortes/:id',
  authorize(1),
  withUser((user, req) =>
    caja.review(
      user,
      req.params.id,
      req.body
    )
  )
);

// ========================================
// AUTORIZACIÓN DEL CHOFER
// ========================================

router.use(authorize(3));

// ========================================
// CATÁLOGOS
// ========================================

router.get('/catalogos', withUser(() =>
  service.catalog()
));

// ========================================
// PARADAS
// ========================================

router.get('/paradas', withUser((user, req) =>
  service.list(
    user,
    optionalDay(req)
  )
));

router.get('/paradas/:id', withUser((user, req) =>
  service.detail(
    user,
    stop(req)
  )
));

router.get(
  '/paradas/:id/historial',
  withUser((user, req) =>
    service.clientVisits(
      user,
      stop(req)
    )
  )
);

router.post(
  '/paradas/:id/inicio',
  withUser((user, req) =>
    service.start(
      user,
      stop(req)
    )
  )
);

router.post(
  '/paradas/:id/fallida',
  withUser((user, req) =>
    service.fail(
      user,
      stop(req),
      req.body
    )
  )
);

router.post(
  '/paradas/:id/cotizacion',
  withUser((user, req) =>
    service.preview(
      user,
      stop(req),
      req.body
    )
  )
);

router.post(
  '/paradas/:id/completar',
  withUser((user, req) =>
    service.complete(
      user,
      stop(req),
      req.body
    )
  )
);

// ========================================
// PAGOS
// ========================================

router.post(
  '/paradas/:id/pagos',
  withUser((user, req) =>
    service.pay(
      user,
      stop(req),
      req.body
    )
  )
);

// ========================================
// MANIFIESTOS
// ========================================

router.get(
  '/paradas/:id/manifiesto',
  withUser((user, req) =>
    service.manifest(
      user,
      stop(req)
    )
  )
);

router.post(
  '/paradas/:id/manifiesto/entrega',
  withUser((user, req) =>
    service.deliver(
      user,
      stop(req)
    )
  )
);

router.get('/manifiestos', withUser((user, req) =>
  service.manifests(
    user,
    optionalDay(req),
    text(
      req.query.folio,
      'Folio',
      50,
      false
    )
  )
));

// ========================================
// EVIDENCIAS
// ========================================

router.get(
  '/paradas/:id/evidencias/:tipo',
  withUser(async (user, req, res) => {
    const bytes = await service.evidence(
      user,
      stop(req),
      req.params.tipo
    );

    res.set('Cache-Control', 'private, no-store');
    res.type(imageType(bytes)).send(bytes);
  })
);

// ========================================
// HISTORIAL DE VENTAS
// ========================================

router.get('/ventas', withUser((user, req) =>
  service.history(
    user,
    optionalDay(req),
    text(
      req.query.cliente,
      'Cliente',
      120,
      false
    ) ?? ''
  )
));

// ========================================
// VIÁTICOS
// ========================================

router.post('/viaticos', withUser((user, req) =>
  caja.expense(
    user,
    req.body
  )
));

// ========================================
// RESUMEN DE CAJA
// ========================================

router.get(
  '/turnos/:id/corte',
  withUser((user, req) =>
    caja.summary(
      user,
      req.params.id,
      day(req)
    )
  )
);

// ========================================
// CIERRE DE TURNO
// ========================================

router.post(
  '/turnos/:id/corte',
  withUser((user, req) =>
    caja.close(
      user,
      req.params.id,
      day(req),
      req.body
    )
  )
);

module.exports = router;
