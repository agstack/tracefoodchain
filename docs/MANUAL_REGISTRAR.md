# Manual: Aplicación del Registrador

> **Idiomas:** [Deutsch](HANDBUCH_REGISTRAR.md) · [English](HANDBOOK_REGISTRAR.md) · **Español**
>
> **Destinatarios:** registradores que trabajan en campo (registro de agricultores, fincas y límites de parcelas)
> **Versión:** agosto de 2026 · Trace Foodchain App
> **Idioma de la app:** se cambia con el icono de idioma arriba a la derecha (DE / EN / ES / FR). Los textos citados en este manual corresponden a la interfaz en español.

---

## Contenido

1. [¿Qué hace el registrador?](#1-qué-hace-el-registrador)
2. [Requisitos](#2-requisitos)
3. [El panel de registro de un vistazo](#3-el-panel-de-registro-de-un-vistazo)
4. [Flujo A: Registrar Finca/Agricultor](#4-flujo-a-registrar-fincaagricultor)
5. [Flujo B: Grabar Límites de Parcela](#5-flujo-b-grabar-límites-de-parcela)
6. [Historial: revisar y corregir los datos](#6-historial-revisar-y-corregir-los-datos)
7. [Trabajar sin conexión y subir los datos](#7-trabajar-sin-conexión-y-subir-los-datos)
8. [Herramientas y ajustes](#8-herramientas-y-ajustes)
9. [Qué ocurre después de la subida (control de calidad)](#9-qué-ocurre-después-de-la-subida-control-de-calidad)
10. [Mensajes y preguntas frecuentes](#10-mensajes-y-preguntas-frecuentes)
11. [Índice de capturas de pantalla](#11-índice-de-capturas-de-pantalla)

---

## 1. ¿Qué hace el registrador?

El registrador captura en campo los datos maestros de la cadena de suministro:

- **Agricultores** (persona, documento de identidad, datos de contacto, formulario de consentimiento)
- **Fincas** (nombre, ubicación, área estimada cultivada con café)
- **Parcelas** (límite recorrido con GPS en forma de polígono, con foto del campo)

Todos los datos se **guardan primero en el dispositivo** y se transfieren a la nube más tarde, en cuanto haya internet. Por eso la aplicación funciona por completo sin conexión.

Cada registro pasa después por el **control de calidad (QC)** del coordinador de registradores (ver [capítulo 9](#9-qué-ocurre-después-de-la-subida-control-de-calidad)).

---

## 2. Requisitos

| Requisito | Motivo |
|---|---|
| Sesión iniciada con la cuenta de registrador | Sin sesión iniciada el almacenamiento local no está abierto y no se puede guardar nada. |
| **GPS activado** y permiso de ubicación concedido | Sin GPS no se puede iniciar ni el registro ni la grabación de parcelas. |
| Permiso de cámara | La foto de identificación, la del formulario de consentimiento y la del campo son obligatorias. |
| Batería cargada / espacio libre | Las fotos permanecen en el dispositivo hasta que se suben. |

> Internet **no** es un requisito para capturar los datos, solo para la subida posterior.

---

## 3. El panel de registro de un vistazo

Tras iniciar sesión como registrador se abre el **Panel de Registro**. Está ordenado de arriba abajo según el flujo de trabajo: *quién soy → puedo trabajar ahora → qué hago → qué he logrado → lo que se usa poco*.

> 📷 **Captura 01** – Panel completo justo después de iniciar sesión (pantalla completa, sección de herramientas plegada).
>
> ![Panel de registro](screenshots/registrar-01-dashboard.png)

### 3.1 Barra superior

| Icono | Función |
|---|---|
| 🌐 Idioma | Cambiar el idioma de la app (DE / EN / ES / FR) |
| 👤 Perfil | **Ver y editar perfil**: foto de perfil, nombre, apellido, número de teléfono |
| ⏻ Cerrar sesión | Salir de la cuenta (con confirmación) |

> 📷 **Captura 02** – Diálogo «Editar perfil» con foto de perfil y campos de entrada.
>
> ![Editar perfil](screenshots/registrar-02-profil.png)

### 3.2 Saludo

Muestra el nombre propio y la etiqueta de rol **REGISTRAR**. Si aparece un correo electrónico en lugar del nombre, es que aún no se han guardado nombre y apellido en el perfil.

### 3.3 Franja de estado: «¿puedo trabajar ahora?»

Tres indicadores uno junto al otro:

**① GPS**

| Indicación | Significado |
|---|---|
| «Buscando» | Todavía se está determinando la posición |
| ± 3 m (verde) | Excelente: menos de 5 m de error |
| ± 8 m (verde claro) | Bueno: menos de 10 m |
| ± 15 m (naranja) | Aceptable: menos de 20 m |
| ± 30 m (rojo) | Malo: no se deberían grabar límites de parcela así |
| «Sin GPS» | Tocar abre las indicaciones para activarlo |

**② Conexión** – «En línea» (verde) o «Sin conexión» (gris). Estar sin conexión no es un error: se sigue trabajando con normalidad.

**③ Estado de subida**

| Indicación | Significado |
|---|---|
| ☁️ «Al día» (verde) | Todo ha llegado a la nube |
| ☁️ «*N* pend.» (naranja) | *N* registros siguen esperando la subida |
| ☁️ «En pausa» (naranja, con contador) | La subida está pausada a propósito; el número indica los registros en espera |

**Al tocarlo se abre el panel de sincronización** con los detalles (ver [capítulo 7](#7-trabajar-sin-conexión-y-subir-los-datos)).

> 📷 **Captura 03** – Primer plano de la franja de estado, preferiblemente con subidas pendientes (naranja).
>
> ![Franja de estado](screenshots/registrar-03-statusstreifen.png)

### 3.4 Las dos tareas principales

| Botón | Tarea |
|---|---|
| 🌱 **Registrar Finca/Agricultor** (verde) | Crear un nuevo agricultor junto con su finca → [capítulo 4](#4-flujo-a-registrar-fincaagricultor) |
| 🗺️ **Grabar Límites de Parcela** (azul) | Recorrer el límite de una parcela de una finca existente → [capítulo 5](#5-flujo-b-grabar-límites-de-parcela) |

Ambos comprueban primero el GPS. Si está apagado aparece **«El GPS debe estar activado para el registro»**: primero se activa el GPS y luego se vuelve a tocar.

> 📷 **Captura 04** – Diálogo «El GPS debe estar activado para el registro».
>
> ![Aviso de GPS](screenshots/registrar-04-gps-hinweis.png)

### 3.5 Rendimiento del día e historial

La tarjeta muestra a la izquierda, en grande, **«Registrados Hoy»**, y a su lado **«Verificado»** (verde) y **«Pendiente»** (naranja).

Así se forman los números: los tres se refieren al **mismo conjunto** (agricultores, fincas, parcelas) **en este dispositivo**:

| Número | Significado |
|---|---|
| Registrados Hoy | Registros creados **hoy** |
| Verificado | Registros que **han pasado** el control de calidad |
| Pendiente | Registros que aún **esperan el QC** |

> El perfil de usuario propio no se cuenta. Los números coinciden exactamente con lo que lista el **Historial**.

En la parte inferior de la tarjeta, **«Ver Historial»** abre la lista completa → [capítulo 6](#6-historial-revisar-y-corregir-los-datos).

> 📷 **Captura 05** – Tarjeta del día con números > 0 y la fila «Ver Historial».
>
> ![Rendimiento del día](screenshots/registrar-05-tagesleistung.png)

### 3.6 Herramientas y ajustes

Sección plegada al final de la página → [capítulo 8](#8-herramientas-y-ajustes).

---

## 4. Flujo A: Registrar Finca/Agricultor

El registro guía por el formulario en **tres pasos**. Cada paso se valida al pulsar «Siguiente»; si falta un dato obligatorio aparece un mensaje abajo y no se puede continuar.

> 📷 **Captura 06** – Vista de los tres pasos (paso 1 abierto).
>
> ![Registro paso 1](screenshots/registrar-06-stepper-uebersicht.png)

### Paso 1 – Información del Agricultor

| Campo | Obligatorio | Nota |
|---|---|---|
| Nombre | ✔ | |
| Apellido | ✔ | |
| Cédula de Identidad (número) | – | se guarda como identificador adicional |
| **Foto de Identificación Nacional** | ✔ | foto del documento; sin ella no se puede continuar |
| Número de Teléfono | – | formato p. ej. `+504-9999-8888` |
| Correo electrónico | – | |

El marco alrededor del área de la foto indica el estado: **rojo** = falta la foto, **verde** = foto tomada (con vista previa). Con **«Volver a Tomar Foto de Identificación»** se repite la toma.

> 📷 **Captura 07** – Paso 1 con los campos llenos y la foto de identificación tomada (marco verde).
>
> ![Información del agricultor](screenshots/registrar-07-landwirt.png)

### Paso 2 – Consentimiento de Uso de Datos

El agricultor firma el formulario de consentimiento en papel; **el formulario firmado se fotografía**. Esta foto también es obligatoria.

> 📷 **Captura 08** – Paso 2 con el formulario de consentimiento fotografiado.
>
> ![Formulario de consentimiento](screenshots/registrar-08-einverstaendnis.png)

### Paso 3 – Información de la Finca

| Campo | Obligatorio | Nota |
|---|---|---|
| Nombre de la Finca | ✔ | |
| ID de Finca | – | identificador interno, si existe |
| Municipio | – | |
| Aldea/Comunidad | – | |
| Estado/Departamento | – | |
| Correo electrónico | – | contacto de la finca |
| Área estimada cultivada con café | – | número **más la unidad** de la lista desplegable contigua |

Con **«Completar Registro»** se crean el agricultor y la finca.

> 📷 **Captura 09** – Paso 3 con el área y la selección de unidad.
>
> ![Información de la finca](screenshots/registrar-09-farm.png)

### Después de finalizar

- El agricultor y la finca se **guardan localmente** con el estado **Pendiente** (esperando el QC).
- Las fotos permanecen de momento en el dispositivo y salen con la siguiente subida.
- Aparece un mensaje de éxito; después el contador del día en el panel sube con los nuevos registros.
- Durante el guardado, una capa superpuesta muestra el progreso (incluido el porcentaje de subida de fotos cuando la subida está activa).

> ⚠️ **Cancelar:** si se abandona el formulario con datos ya introducidos, la app pregunta si se deben **descartar**. Los datos descartados no se pueden recuperar.

> 📷 **Captura 10** – Capa de progreso o mensaje de éxito tras finalizar.
>
> ![Registro completado](screenshots/registrar-10-abschluss.png)

---

## 5. Flujo B: Grabar Límites de Parcela

### 5.1 Seleccionar la finca (obligatorio)

Una parcela **pertenece siempre a una finca**, por eso primero se selecciona la finca.

- Si aún no hay ninguna finca registrada aparece **«Aún no hay fincas registradas»** con el botón **«Registrar Finca»**, que lleva directamente al [flujo A](#4-flujo-a-registrar-fincaagricultor).
- La finca seleccionada se muestra después en la barra superior; con el icono ✏️ se puede cambiar (**«Cambiar Finca»**).

> 📷 **Captura 11** – Selección de finca antes de comenzar la grabación.
>
> ![Selección de finca](screenshots/registrar-11-farmauswahl.png)

### 5.2 Grabaciones sin terminar

Si hay **grabaciones de campo sin terminar**, la app pregunta al iniciar: **«¿Continuar o empezar nuevo?»**: se puede seguir recorriendo el área ya empezada o pulsar **«Comenzar nuevo campo»**.

### 5.3 Recorrer el límite

El límite de la parcela se recorre punto por punto:

| Elemento | Función |
|---|---|
| **Agregar Punto** | Tomar la posición GPS actual como vértice |
| Lista de puntos / mapa | Muestra los puntos colocados y el área resultante |
| Tocar un punto → **¿Eliminar Punto?** | Quitar un punto mal colocado (con confirmación) |
| **Borrar Polígono** | Reiniciar la grabación por completo |
| Indicador de precisión | Precisión actual del GPS en metros |

Reglas al colocar los puntos:

- Se requieren **al menos 3 puntos**, de lo contrario: «Se requieren al menos 3 puntos».
- Dos puntos deben estar separados **al menos 5 m**, de lo contrario: «Punto demasiado cerca del punto anterior».
- Antes de guardar, la app pregunta si el polígono debe **cerrarse automáticamente** (último punto de vuelta al primero). Se muestra el área calculada.
- Con mala precisión de GPS (indicador rojo) conviene esperar un momento hasta que la señal se estabilice.

> 📷 **Captura 12** – Grabación en curso: mapa con los puntos, contador de puntos e indicador de precisión.
>
> ![Grabar límites de parcela](screenshots/registrar-12-polygon.png)

### 5.4 Foto del Campo (obligatoria)

La **Foto del Campo** se toma con el icono de cámara de la barra superior. El icono lleva una marca de color:

| Marca | Significado |
|---|---|
| 🟠 Señal de aviso | Falta la foto |
| 🟢 Marca de verificación | Foto presente y válida |
| 🔴 Cruz | Foto inválida: fue tomada **fuera del polígono** |

La foto debe tomarse **dentro del área grabada** (tolerancia de 50 m); sirve como prueba de que el registrador estuvo realmente en el sitio.

> 📷 **Captura 13** – Diálogo de la foto del campo con estado válido (verde).
>
> ![Foto del campo](screenshots/registrar-13-feldfoto.png)

### 5.5 Guardar

**«Registrar Parcela»** crea la parcela y la vincula con la finca seleccionada. Esta parcela también empieza con el estado **Pendiente**. Como alternativa, la grabación puede interrumpirse con **«Guardar y Salir»** y continuarse más tarde.

---

## 6. Historial: revisar y corregir los datos

**Panel → «Ver Historial»** abre el historial de registros completo de este dispositivo.

Posibilidades:

- **Filtrar** por *Todos / Agricultores / Fincas / Parcelas* y **buscar** por nombre
- Consultar el **estado** de cada entrada (verificado / pendiente / rechazado) junto con la fecha de registro
- **Editar una entrada**: corregir los datos maestros, volver a tomar la foto de identificación o la del consentimiento
- **Agregar una finca a un agricultor** (un agricultor puede tener varias fincas)
- **Agregar una parcela a una finca** (una finca puede tener varias parcelas)
- Ver el área y el fragmento de mapa de una parcela

> 📷 **Captura 14** – Historial con la barra de filtros y varias entradas en distintos estados.
>
> ![Historial](screenshots/registrar-14-verlauf.png)

> 📷 **Captura 15** – Vista de detalle/edición de una entrada.
>
> ![Editar entrada](screenshots/registrar-15-eintrag-bearbeiten.png)

---

## 7. Trabajar sin conexión y subir los datos

### 7.1 Principio básico

La captura funciona **completamente sin internet**. Cada registro se guarda de inmediato en local y se coloca en una cola de subida. En cuanto el dispositivo está en línea, la cola se procesa:

- automáticamente cada **10 minutos** aproximadamente, mientras el panel esté abierto y la subida no esté pausada,
- o de inmediato con **«Sincronizar ahora»** en el panel de sincronización.

### 7.2 El panel de sincronización

Accesible desde el **indicador de subida de la franja de estado** o desde *Herramientas y ajustes*.

| Elemento | Significado |
|---|---|
| **Pausar la subida** (interruptor) | Apagado = «Subida activa». Encendido = «Subida en pausa: los datos se guardan solo localmente» |
| Lista de elementos en espera | Qué queda exactamente en cola, con tipo y motivo |
| Última sincronización correcta | Hora o fecha |
| Próximo reintento / último error | Solo aparece cuando una subida se ha quedado atascada |
| **Sincronizar ahora** | Inicia la subida de inmediato |

> 📷 **Captura 16** – Panel de sincronización con el interruptor de pausa y la lista de subidas pendientes.
>
> ![Panel de sincronización](screenshots/registrar-16-sync-panel.png)

### 7.3 ¿Cuándo conviene pausar la subida?

En zonas remotas con **cobertura móvil muy débil**, las fotos grandes bloquean la subida y ralentizan el trabajo. En ese caso:

1. activar **Pausar la subida**,
2. seguir capturando con normalidad durante el día (todo se guarda localmente),
3. por la tarde, con buena conexión (p. ej. wifi de la oficina), desactivar el interruptor y pulsar **«Sincronizar ahora»**.

> ⚠️ Mientras esté en pausa, los datos existen **solo en el dispositivo**. Solo están seguros tras una subida correcta: no restablecer el dispositivo ni desinstalar la app mientras se muestren subidas pendientes.

---

## 8. Herramientas y ajustes

La sección plegada al final del panel contiene:

| Ajuste | Significado |
|---|---|
| **Unidad de área** | Unidad para mostrar el tamaño del campo. El botón de la derecha alterna entre las unidades válidas para el país. |
| **Sección de sincronización** | El mismo panel del [capítulo 7](#72-el-panel-de-sincronización): pausar la subida, elementos en espera, última sincronización, sincronizar ahora. |

> 📷 **Captura 17** – Sección «Herramientas y ajustes» desplegada.
>
> ![Herramientas y ajustes](screenshots/registrar-17-werkzeuge.png)

> ℹ️ **Nota sobre el directorio de productores de IHCafé:** el directorio **no** se carga en los dispositivos de los registradores de forma deliberada, ya que el conjunto de datos completo ocupa varios megabytes. Solo está disponible para el **coordinador de registradores en la vista de QC (aplicación web)**; la asociación de un registro con un productor de IHCafé se realiza allí.

---

## 9. Qué ocurre después de la subida (control de calidad)

1. El registrador captura los datos → estado **Pendiente**.
2. Los datos se transfieren a la nube.
3. El **coordinador de registradores** los revisa en la vista de QC: fotos, ubicación, plausibilidad de los datos y, en su caso, cotejo con el directorio de productores de IHCafé.
4. Resultado:
   - **Verificado**: el registro queda aprobado y cuenta en «Verificado» en el panel.
   - **Rechazado**: el registro aparece como rechazado en el historial y debe corregirse.

Por eso: **tomar fotos nítidas y completas** y escribir los nombres con cuidado; cada corrección significa una segunda visita al agricultor.

---

## 10. Mensajes y preguntas frecuentes

| Mensaje / situación | Causa | Solución |
|---|---|---|
| «El GPS debe estar activado para el registro» | Servicio de ubicación apagado o sin permiso | Activar el GPS en el dispositivo, conceder el permiso de ubicación a la app y volver a empezar |
| Se exige la foto de identificación o de consentimiento | Falta una foto obligatoria | Tomar la foto; solo entonces se puede avanzar |
| «Se requieren al menos 3 puntos» | El polígono tiene muy pocos vértices | Colocar más puntos a lo largo del límite de la parcela |
| «Punto demasiado cerca del punto anterior (mín 5m)» | Dos puntos están demasiado juntos | Caminar un poco más antes de colocar el siguiente punto |
| Foto del campo marcada en rojo | La foto se tomó fuera del polígono | Situarse dentro del área grabada y repetir la foto (tolerancia de 50 m) |
| «El campo debe estar vinculado a una finca» | No se ha seleccionado ninguna finca | Seleccionar una finca o registrar una primero |
| «Aún no hay fincas registradas» | Todavía no existe un registro para esa finca | Con **«Registrar Finca»** crear primero el agricultor y la finca |
| El indicador muestra siempre «*N* pend.» | Sin conexión, subida pausada o error de subida | Abrir el panel de sincronización: desactivar la pausa, comprobar la conexión, leer el mensaje de error y pulsar **«Sincronizar ahora»** |
| Los números del panel parecen bajos | Los números solo abarcan los registros de **este dispositivo** | Es normal; la visión global la tiene el coordinador de registradores |
| Aparece un correo electrónico en lugar del nombre | Faltan nombre y apellido en el perfil | Completar el nombre desde el icono de perfil y guardar |

---

## 11. Índice de capturas de pantalla

Guardar todas las imágenes en `docs/screenshots/`. Recomendado: orientación vertical, ancho del dispositivo ≥ 1080 px, PNG. Los manuales en alemán, inglés y español usan los **mismos** nombres de archivo: un único juego de capturas sirve para los tres, o bien se puede mantener un juego por idioma en subcarpetas y ajustar las rutas.

| N.º | Nombre de archivo | Motivo |
|---|---|---|
| 01 | `registrar-01-dashboard.png` | Panel completo después de iniciar sesión |
| 02 | `registrar-02-profil.png` | Diálogo «Editar perfil» |
| 03 | `registrar-03-statusstreifen.png` | Franja de estado (GPS / conexión / subidas), preferiblemente con subidas pendientes |
| 04 | `registrar-04-gps-hinweis.png` | Diálogo «El GPS debe estar activado para el registro» |
| 05 | `registrar-05-tagesleistung.png` | Tarjeta del día con números y «Ver Historial» |
| 06 | `registrar-06-stepper-uebersicht.png` | Formulario de registro con los tres pasos visibles |
| 07 | `registrar-07-landwirt.png` | Paso 1 con la foto de identificación (marco verde) |
| 08 | `registrar-08-einverstaendnis.png` | Paso 2 con el formulario de consentimiento fotografiado |
| 09 | `registrar-09-farm.png` | Paso 3 con el área y la selección de unidad |
| 10 | `registrar-10-abschluss.png` | Capa de progreso o mensaje de éxito |
| 11 | `registrar-11-farmauswahl.png` | Selección de finca en el grabador de límites |
| 12 | `registrar-12-polygon.png` | Grabación del polígono en curso con los puntos |
| 13 | `registrar-13-feldfoto.png` | Diálogo de la foto del campo, estado válido |
| 14 | `registrar-14-verlauf.png` | Historial con filtros y entradas |
| 15 | `registrar-15-eintrag-bearbeiten.png` | Vista de detalle/edición de una entrada |
| 16 | `registrar-16-sync-panel.png` | Panel de sincronización con el interruptor de pausa |
| 17 | `registrar-17-werkzeuge.png` | Sección «Herramientas y ajustes» desplegada |
