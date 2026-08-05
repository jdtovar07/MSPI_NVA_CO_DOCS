# ms_org — Análisis

| Campo | Valor |
|---|---|
| Repositorio | `MSPI_NVA_CO_MR_BACK/ms_org` |
| Fecha del documento | 2026-08-19 |
| Alcance | Requerimientos funcionales y no funcionales, reglas de negocio, actores y casos de uso reales del microservicio `ms_org`, extraídos del código (`domain/usecase`, `domain/model`, adaptadores) y de `docs/openapi.yaml` / `docs/MVP-MSPI-CONTRATOS-Y-MER.md` |

---

## 1. Actores del sistema

| Actor | Tipo | Rol Keycloak requerido | Descripción |
|---|---|---|---|
| Administrador del sistema | Humano | `AdminSistema` (`ROLE_AdminSistema`) | Da de alta, consulta, lista y actualiza organizaciones. Acceso a todo `/organizations/**` salvo `/my-organization`. |
| Usuario Lector | Humano | `Lector` (`ROLE_Lector`) | Representante de la organización evaluada; consulta únicamente los datos de su propia organización vía `GET /organizations/my-organization`. Se aprovisiona automáticamente al crear la organización. |
| Visitante anónimo / frontend público | No autenticado | — | Consume `/location/**` (catálogo geográfico) sin JWT, típicamente durante el llenado del formulario de alta de organización. |
| `ms_iam` (sistema) | Microservicio | — (llamada saliente desde `ms_org`, no entrante) | Recibe `POST /users` y `POST /users/disable-by-email` desde `ms_org`; a su vez consulta `GET /organizations/{id}` hacia `ms_org` para validar organizaciones. |
| Country State City API (sistema externo) | Servicio externo | API key propia (`X-CSCAPI-KEY`) | Fuente de datos de países/estados/ciudades consumida por `LocationCatalogAdapter`. |

## 2. Requerimientos funcionales

Derivados de los endpoints implementados (`OrganizationApi`, `LocationApi`) y de las historias de usuario referenciadas en `docs/MVP-MSPI-CONTRATOS-Y-MER.md`:

| ID | Requerimiento | Endpoint(s) | HU asociada |
|---|---|---|---|
| RF-01 | Crear una organización con sus datos maestros y su contacto principal, provisionando automáticamente un usuario `Lector` en `ms_iam` | `POST /organizations` | HU-MVP-001 |
| RF-02 | Listar organizaciones de forma paginada, con filtros opcionales por nombre, identificador, tipo y estado | `GET /organizations` | HU-MVP-002 |
| RF-03 | Consultar el detalle de una organización por su UUID | `GET /organizations/{organizationId}` | HU-MVP-002 |
| RF-04 | Actualizar los datos de una organización existente, incluyendo la posibilidad de cambiar el correo del contacto principal (con sincronización en `ms_iam`) | `PUT /organizations/{organizationId}` | HU-MVP-003 |
| RF-05 | Permitir que un usuario `Lector` consulte los datos de su propia organización sin conocer su UUID explícitamente | `GET /organizations/my-organization` | HU-MVP-008 |
| RF-06 | Exponer el catálogo de países disponibles para formularios | `GET /location/countries` | — (soporte a HU-MVP-001) |
| RF-07 | Exponer el catálogo de departamentos/estados de un país dado su código ISO2 | `GET /location/countries/{countryIso2}/states` | — (soporte a HU-MVP-001) |
| RF-08 | Exponer el catálogo de ciudades de un departamento/estado dado | `GET /location/countries/{countryIso2}/states/{stateIso2}/cities` | — (soporte a HU-MVP-001) |
| RF-09 | Revertir automáticamente la creación de una organización si falla el aprovisionamiento del usuario `Lector` en `ms_iam` | Lógica interna de `CreateOrganizationGatewayAdapter` | — (regla derivada, no HU explícita) |
| RF-10 | Desactivar en `ms_iam` al usuario `Lector` asociado al correo anterior cuando el correo de contacto cambia en una actualización | Lógica interna de `UpdateOrganizationUseCase` | — (regla derivada) |

## 3. Requerimientos no funcionales

| ID | Requerimiento | Evidencia en el código |
|---|---|---|
| RNF-01 | Todas las respuestas exitosas deben seguir el envoltorio uniforme `CorrectResponse` (`meta.traceId`, `meta.timestamp`, `data`) | `ApiResponseMapper.success`, usado en `OrganizationApi` y `LocationApi` |
| RNF-02 | Todos los errores deben seguir el envoltorio `ErrorResponse` con código de error semántico (`NOT_FOUND`, `VALIDATION`, `BUSINESS_RULES`, `USER_ALREADY_EXISTS`, `IAM_SERVICE_ERROR`, `INTERNAL_ERROR`) | `GlobalExceptionHandler`, `CommonErrorConstants` |
| RNF-03 | Toda petición HTTP debe ser trazable mediante un `traceId` propagado o generado, expuesto también en la cabecera de respuesta | `TraceIdFilter` (`X-Trace-Id`), `MDC` |
| RNF-04 | El acceso a los recursos de organización debe estar controlado por rol de forma diferenciada según la ruta (RBAC) | `SecurityConfig.securityFilterChain` |
| RNF-05 | Los orígenes CORS permitidos deben ser configurables externamente y no estar *hardcodeados* | `CorsConfig`, variable `CORS_ALLOWED_ORIGINS` |
| RNF-06 | El microservicio no debe ejecutar DDL automáticamente contra la base de datos | `spring.sql.init.mode: never`, `hibernate.ddl-auto: none` en `application.yaml` |
| RNF-07 | Las credenciales de base de datos y demás secretos no deben estar en texto plano en el repositorio; deben resolverse en tiempo de arranque desde un gestor de secretos | `InfisicalConfig`, `DBCredentialConfig` (falla explícitamente si `DB_CREDENTIAL` no está presente) |
| RNF-08 | Las cabeceras de seguridad HTTP estándar deben estar activas (HSTS, `X-Frame-Options: DENY`) y CSRF debe estar deshabilitado por tratarse de una API *stateless* | `SecurityConfig.securityFilterChain` (`.headers(...)`, `.csrf(disable)`, `SessionCreationPolicy.STATELESS`) |
| RNF-09 | El servicio debe degradar con gracia (lista vacía, no excepción) si la API externa de ubicación no está disponible o no tiene API key configurada | `LocationCatalogAdapter` (`try/catch` que retorna `List.of()`, chequeo `hasApiKey()`) |
| RNF-10 | El contenedor Docker debe ejecutar el proceso como usuario no privilegiado y exponer un healthcheck nativo | `deployment/Dockerfile` (`USER mspi`, `HEALTHCHECK`) |

## 4. Reglas de negocio (extraídas de `domain/usecase` y adaptadores)

### 4.1 Creación de organización (`CreateOrganizationUseCase` → `CreateOrganizationGatewayAdapter`)

1. El correo de contacto (`organizationEmail`) es **obligatorio** en el `POST` — validado explícitamente en `OrganizationApi.create` (no en el DTO, para no exigirlo también en `PUT`), lanzando `BusinessRulesOnFieldsException` si falta.
2. El nombre es obligatorio (`@NotBlank` en `OrganizationRequest` + verificación redundante en `OrganizationJpaAdapter.save`).
3. La combinación `(name, identifier)` debe ser única; `OrganizationRepository.countByNameAndIdentifierExcludingId` se invoca antes de guardar, y la restricción está reforzada también a nivel de base de datos (`idx_org_name_identifier_unique`).
4. Si `status` no se especifica, se asigna `ACTIVE` por defecto (`OrganizationApiMapper.toDomain` y `OrganizationJpaAdapter.save`).
5. Tras persistir la organización, se persiste el contacto principal (`organization_contact`, `role=Lector`, `is_primary=true`) y se llama a `ms_iam` para crear el usuario `Lector` con ese correo.
6. **Regla de compensación**: si la llamada a `ms_iam` lanza excepción (correo duplicado → 409, servicio caído → 502), `CreateOrganizationGatewayAdapter` ejecuta `rollbackOrganizationCreation`, que elimina el contacto y la organización recién creados, y relanza la excepción original hacia el controlador. No hay transacción distribuida real (2PC): es una compensación manual a nivel de aplicación.

### 4.2 Actualización de organización (`UpdateOrganizationUseCase`)

1. La actualización es un `PUT` completo: los campos no enviados conservan el valor existente (`OrganizationJpaAdapter.update` aplica `campo != null ? nuevo : existente` por campo).
2. Se revalida la unicidad `(name, identifier)` excluyendo el propio id (`countByNameAndIdentifierExcludingId(..., id)`).
3. Si el `organizationEmail` enviado en el request difiere del correo actualmente registrado como contacto principal, se ejecuta la **sincronización con IAM**: desactivar el usuario anterior (`disableUserByEmail`), actualizar el contacto principal en base de datos, y crear el nuevo usuario `Lector` con el correo nuevo. Si el correo no cambia o no se envía, no se toca IAM.
4. `disableUserByEmail` **no relanza excepción** si `ms_iam` responde con error — se asume que si el usuario no existe en IAM, "no hay nada que desactivar", priorizando que la actualización de la organización no falle por un efecto secundario no crítico.

### 4.3 Consulta propia (`GetMyOrganizationUseCase`, `OrganizationApi.getMyOrganization`)

1. El `organizationId` se resuelve en este orden de prioridad: (1) header `X-Organization-Id` si es un UUID válido, (2) claim `organization_id` del JWT si es un UUID válido, (3) `null` si ninguno aplica.
2. Si el `organizationId` resuelto es `null`, `OrganizationJpaAdapter.findById` lanza `ResourceNotFoundException("Usuario sin organización asociada")` → HTTP 404 (no HTTP 400, decisión de diseño real observada en el código pese a que conceptualmente podría considerarse un caso de validación).

### 4.4 Catálogo de ubicación (`GetCountriesUseCase`, `GetStatesByCountryUseCase`, `GetCitiesByStateUseCase`)

1. Los parámetros de país/estado se normalizan a mayúsculas y se recortan (`trim().toUpperCase()`) antes de consultar la API externa.
2. Si el parámetro requerido está vacío o nulo, el caso de uso retorna lista vacía sin siquiera invocar el gateway (corte temprano, sin excepción).
3. Los resultados se ordenan alfabéticamente por nombre (`Comparator.comparing(..., String.CASE_INSENSITIVE_ORDER)`) del lado del adaptador, no de la API externa.
4. Ante cualquier error de la API externa (timeout, 4xx/5xx, JSON inesperado) el adaptador captura la excepción, la registra en log y retorna lista vacía — nunca propaga el error al cliente HTTP.

## 5. Casos de uso (resumen técnico)

| Caso de uso (clase) | Entrada | Salida | Gateway(s) invocado(s) |
|---|---|---|---|
| `CreateOrganizationUseCase` | `Organization` (sin id) | `CreateOrganizationResult` (id) | `CreateOrganizationGateway` |
| `GetOrganizationsUseCase` | page, size, name, identifier, type, status | `PagedOrganizations` | `OrganizationPersistenceGateway` |
| `GetOrganizationByIdUseCase` | `UUID id` | `Organization` | `OrganizationPersistenceGateway` |
| `UpdateOrganizationUseCase` | `UUID id`, `Organization` | `void` (efecto: persistencia + posible sincronización IAM) | `OrganizationPersistenceGateway`, `IamGateway` |
| `GetMyOrganizationUseCase` | `UUID organizationId` | `Organization` | `OrganizationPersistenceGateway` |
| `GetCountriesUseCase` | — | `List<CountryLocation>` | `LocationCatalogGateway` |
| `GetStatesByCountryUseCase` | `String countryIso2` | `List<StateLocation>` | `LocationCatalogGateway` |
| `GetCitiesByStateUseCase` | `String countryIso2`, `String stateIso2` | `List<CityLocation>` | `LocationCatalogGateway` |

Los ocho casos de uso son clases planas (`@RequiredArgsConstructor`, sin anotaciones de Spring) que reciben sus gateways por constructor — el ensamblaje real ocurre en `UseCaseConfig` (módulo `app-service`), manteniendo el módulo `:usecase` libre de dependencias de framework, tal como en `ms_iam`.

## 6. Flujos de error mapeados a HTTP

| Excepción de dominio | Código HTTP | Código de error | Disparador típico |
|---|---|---|---|
| `ResourceNotFoundException` | 404 | `NOT_FOUND` | Organización inexistente, contacto principal inexistente, `organizationId` nulo en `my-organization` |
| `BusinessRulesOnFieldsException` | 400 | `BUSINESS_RULES` | Nombre vacío, `(name, identifier)` duplicado, correo de organización faltante en creación |
| `MethodArgumentNotValidException` (Bean Validation) | 400 | `VALIDATION` | Campos `@NotBlank` de `OrganizationRequest` incumplidos |
| `UserAlreadyExistsException` | 409 | `USER_ALREADY_EXISTS` | `ms_iam` responde `DUPLICATE_EMAIL` al crear el usuario `Lector` |
| `IamServiceException` | 502 | `IAM_SERVICE_ERROR` | `ms_iam` no responde, error de red, o error no reconocido como duplicado |
| `DomainException` | 500 | `INTERNAL_ERROR` | Cualquier excepción de dominio no específica (red de seguridad genérica) |

## 7. Brechas / ausencias identificadas en el análisis

- **No hay eliminación (`DELETE`) de organizaciones** — el ciclo de vida documentado solo contempla creación, consulta y actualización; el "borrado" se modelaría, si acaso, cambiando `status` (campo libre, sin enumeración validada en código: `status` es `String`, no `enum`).
- **`status` y `type` no están validados contra una lista cerrada de valores** en ningún punto del backend (ni `@Pattern` ni `enum`); el OpenAPI los documenta como `string` libre. Cualquier valor es aceptado.
- **No existe endpoint para gestionar contactos adicionales** (`organization_contact` soporta múltiples contactos por organización vía `organization_id`, pero solo se gestiona el contacto principal desde la API expuesta).
- **La reversión ante fallo de IAM no es atómica con la propia creación**: son tres operaciones JPA con `@Transactional(propagation = REQUIRES_NEW)` independientes (guardar organización, guardar contacto, rollback manual), por lo que existe una ventana teórica de inconsistencia si el proceso se interrumpe exactamente entre el `save` y el `rollbackOrganizationCreation` (p. ej. caída del proceso a mitad de la llamada a IAM).
