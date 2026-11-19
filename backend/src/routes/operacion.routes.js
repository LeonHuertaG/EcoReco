const express = require("express");

const { authorize } = require("../middleware/session");

const { date, id, RequestError } = require("../services/chofer-domain");

const catalogs = require("../services/operacion-catalogos");
const agenda = require("../services/operacion-agenda");
const consultas = require("../services/operacion-consultas");

const router = express.Router();

// ========================================
// RESPUESTAS Y ERRORES
// ========================================

const respond = (handler) => (req, res, next) =>
  Promise.resolve()
    .then(() => handler(req))
    .then((data) => res.json(data))
    .catch(next);

const commercial = (req, res, next) =>
  [1, 2].includes(req.user.fk_rol)
    ? next()
    : next(new RequestError("Acceso denegado.", 403));

function requireRole(role) {
  return (req, res, next) =>
    req.user.fk_rol === role
      ? next()
      : next(new RequestError("Acceso denegado.", 403));
}

// Todas las rutas requieren autenticación
router.use(authorize());

// ========================================
// CATÁLOGOS
// ========================================

router.get(
  "/catalogos",
  commercial,
  respond((req) => catalogs.menu(req.user.fk_rol)),
);

router.get(
  "/catalogos/:resource",
  commercial,
  respond((req) =>
    catalogs.list(
      req.params.resource,
      req.user.fk_rol,
      id(req.query.pagina ?? 1),
    ),
  ),
);

router.post(
  "/catalogos/:resource",
  commercial,
  respond((req) =>
    catalogs.save(req.user, req.params.resource, null, req.body),
  ),
);

router.post(
  "/catalogos/:resource/:id",
  commercial,
  respond((req) =>
    catalogs.save(req.user, req.params.resource, req.params.id, req.body),
  ),
);

router.post(
  "/catalogos/:resource/:id/estado",
  commercial,
  respond((req) =>
    catalogs.setActive(
      req.user,
      req.params.resource,
      req.params.id,
      req.body.activo,
    ),
  ),
);

// ========================================
// AGENDA Y RECOLECCIONES
// ========================================

router.get(
  "/agenda",
  commercial,
  respond((req) =>
    agenda.agenda(req.query.fecha == null ? null : date(req.query.fecha)),
  ),
);

router.post(
  "/agenda/generar",
  commercial,
  respond((req) => agenda.generate(req.user.pk_usuario, req.body)),
);

router.post(
  "/agenda/programar",
  commercial,
  respond((req) => agenda.schedule(req.user.pk_usuario, req.body)),
);

router.post(
  "/agenda/asignar",
  commercial,
  respond((req) => agenda.assign(req.user.pk_usuario, req.body)),
);

router.post(
  "/agenda/:id/desasignar",
  commercial,
  respond((req) => agenda.unassign(req.user.pk_usuario, req.params.id)),
);

// ========================================
// PORTAL DEL CLIENTE
// ========================================

router.get(
  "/cliente/visitas",
  requireRole(4),
  respond((req) => agenda.customerVisits(req.user.pk_usuario)),
);

router.post(
  "/cliente/visitas/:id",
  requireRole(4),
  respond((req) =>
    agenda.customerAction(req.user.pk_usuario, req.params.id, req.body),
  ),
);

// ========================================
// ESTADO DE CUENTA DEL CLIENTE
// ========================================

router.get(
  "/cliente/cuenta",
  requireRole(4),
  respond((req) => consultas.customerAccount(req.user.pk_usuario)),
);

// ========================================
// MANIFIESTOS DEL CLIENTE
// ========================================

router.get(
  "/cliente/manifiestos/:id",
  requireRole(4),
  respond((req) =>
    consultas.customerManifest(req.user.pk_usuario, req.params.id),
  ),
);

// ========================================
// REPORTES ADMINISTRATIVOS
// ========================================

router.get(
  "/reportes",
  requireRole(1),
  respond((req) =>
    consultas.reports(
      date(req.query.fecha ?? agenda.today()),
      req.app.locals.metrics,
    ),
  ),
);

module.exports = router;
