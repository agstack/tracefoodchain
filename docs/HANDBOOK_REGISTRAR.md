# Handbook: Registrar App

> **Languages:** [Deutsch](HANDBUCH_REGISTRAR.md) · **English** · [Español](MANUAL_REGISTRAR.md)
>
> **Audience:** Registrars working in the field (recording farmers, farms and field boundaries)
> **Version:** August 2026 · Trace Foodchain App
> **App language:** switch with the language icon in the top right (DE / EN / ES / FR). The labels quoted in this handbook are the English ones.

---

## Contents

1. [What does a registrar do?](#1-what-does-a-registrar-do)
2. [Prerequisites](#2-prerequisites)
3. [The dashboard at a glance](#3-the-dashboard-at-a-glance)
4. [Workflow A: Register Farm/Farmer](#4-workflow-a-register-farmfarmer)
5. [Workflow B: Record Field Boundary](#5-workflow-b-record-field-boundary)
6. [History: reviewing and correcting your data](#6-history-reviewing-and-correcting-your-data)
7. [Working offline and uploading data](#7-working-offline-and-uploading-data)
8. [Tools & settings](#8-tools--settings)
9. [What happens after the upload (quality control)](#9-what-happens-after-the-upload-quality-control)
10. [Messages and frequently asked questions](#10-messages-and-frequently-asked-questions)
11. [Screenshot index](#11-screenshot-index)

---

## 1. What does a registrar do?

The registrar records the master data of the supply chain in the field:

- **Farmers** (person, ID document, contact details, consent form)
- **Farms** (name, location, estimated coffee-planted area)
- **Fields / plots** (field boundary walked with GPS as a polygon, plus a field photo)

All data is **stored on the device first** and transferred to the cloud later, as soon as internet is available. The app is therefore fully usable offline.

Every registration then goes into **quality control (QC)** performed by the registrar coordinator (see [chapter 9](#9-what-happens-after-the-upload-quality-control)).

---

## 2. Prerequisites

| Requirement | Why |
|---|---|
| Signed in with the registrar account | Without a sign-in the local data store is not open and nothing can be saved. |
| **GPS enabled** and location permission granted | Without GPS neither registration nor field recording can be started. |
| Camera permission | The ID photo, consent form photo and field photo are all mandatory. |
| Charged battery / free storage | Photos stay on the device until they are uploaded. |

> Internet is **not** required for data capture – only for the later upload.

---

## 3. The dashboard at a glance

After signing in as a registrar the **Registrar Dashboard** opens. It follows the order of work from top to bottom: *who am I → can I work right now → what do I do → what have I achieved → rarely used items*.

> 📷 **Screenshot 01** – The complete dashboard right after login (full screen, tools section collapsed).
>
> ![Registrar dashboard](screenshots/registrar-01-dashboard.png)

### 3.1 Top bar

| Icon | Function |
|---|---|
| 🌐 Language | Switch the app language (DE / EN / ES / FR) |
| 👤 Profile | **View and edit profile**: profile photo, first name, last name, phone number |
| ⏻ Logout | Sign out (with confirmation) |

> 📷 **Screenshot 02** – "Edit Profile" dialog with profile photo and input fields.
>
> ![Edit profile](screenshots/registrar-02-profil.png)

### 3.2 Greeting

Shows your own name and the role badge **REGISTRAR**. If an email address appears instead of a name, no first/last name has been stored in the profile yet.

### 3.3 Status strip – "can I work right now?"

Three indicators side by side:

**① GPS**

| Display | Meaning |
|---|---|
| "Searching" | Position is still being determined |
| ± 3 m (green) | Excellent – below 5 m of error |
| ± 8 m (light green) | Good – below 10 m |
| ± 15 m (orange) | Fair – below 20 m |
| ± 30 m (red) | Poor – field boundaries should not be recorded like this |
| "No GPS" | Tap to open the instructions for enabling it |

**② Connection** – "Online" (green) or "Offline" (grey). Offline is not an error: you simply keep working.

**③ Upload status**

| Display | Meaning |
|---|---|
| ☁️ "Synced" (green) | Everything has reached the cloud |
| ☁️ "*N* open" (orange) | *N* records are still waiting to be uploaded |
| ☁️ "Paused" (orange, with number badge) | Uploads are deliberately paused; the badge shows the waiting records |

**Tapping it opens the sync panel** with the details (see [chapter 7](#7-working-offline-and-uploading-data)).

> 📷 **Screenshot 03** – Close-up of the status strip, ideally with open uploads (orange).
>
> ![Status strip](screenshots/registrar-03-statusstreifen.png)

### 3.4 The two main tasks

| Button | Task |
|---|---|
| 🌱 **Register Farm/Farmer** (green) | Create a new farmer together with a farm → [chapter 4](#4-workflow-a-register-farmfarmer) |
| 🗺️ **Record Field Boundary** (blue) | Walk the boundary of a field belonging to an existing farm → [chapter 5](#5-workflow-b-record-field-boundary) |

Both check GPS first. If it is off, **"GPS must be enabled for registration"** appears – enable GPS, then tap again.

> 📷 **Screenshot 04** – "GPS must be enabled for registration" dialog.
>
> ![GPS notice](screenshots/registrar-04-gps-hinweis.png)

### 3.5 Daily performance and history

The card shows **"Registered Today"** as a large number on the left, with **"Verified"** (green) and **"Pending"** (orange) next to it.

How the numbers are built – all three describe the **same set** (farmers, farms, fields/plots) **on this device**:

| Number | Meaning |
|---|---|
| Registered Today | Records created **today** |
| Verified | Records that **passed** quality control |
| Pending | Records still **waiting for QC** |

> Your own user profile is not counted. The numbers match exactly what the **History** screen lists.

At the bottom of the card, **"View History"** opens the full list → [chapter 6](#6-history-reviewing-and-correcting-your-data).

> 📷 **Screenshot 05** – Daily card with numbers > 0 and the "View History" row.
>
> ![Daily performance](screenshots/registrar-05-tagesleistung.png)

### 3.6 Tools & settings

Collapsed section at the bottom of the page → [chapter 8](#8-tools--settings).

---

## 4. Workflow A: Register Farm/Farmer

The registration guides you through the form in **three steps**. Each step is validated when you tap onwards; if a mandatory entry is missing, a message appears at the bottom and you cannot continue.

> 📷 **Screenshot 06** – Stepper overview with the three steps (step 1 open).
>
> ![Registration step 1](screenshots/registrar-06-stepper-uebersicht.png)

### Step 1 – Farmer Information

| Field | Mandatory | Note |
|---|---|---|
| First Name | ✔ | |
| Last Name | ✔ | |
| National ID (number) | – | stored as an additional identifier |
| **National ID Photo** | ✔ | photo of the ID document; without it you cannot continue |
| Phone Number | – | format e.g. `+504-9999-8888` |
| Email | – | |

The frame around the photo area shows the state: **red** = photo missing, **green** = photo taken (with preview). **"Retake ID Photo"** repeats the shot.

> 📷 **Screenshot 07** – Step 1 with filled fields and a captured ID photo (green frame).
>
> ![Farmer information](screenshots/registrar-07-landwirt.png)

### Step 2 – Data Usage Consent

The farmer signs the consent form on paper; **the signed form is photographed**. This photo is mandatory as well.

> 📷 **Screenshot 08** – Step 2 with the photographed consent form.
>
> ![Consent form](screenshots/registrar-08-einverstaendnis.png)

### Step 3 – Farm Information

| Field | Mandatory | Note |
|---|---|---|
| Farm Name | ✔ | |
| Farm ID | – | internal identifier, if one exists |
| Municipality | – | |
| Village/Community | – | |
| State/Department | – | |
| Email | – | contact of the farm |
| Estimated coffee-planted area | – | number **plus the unit** from the dropdown next to it |

**"Complete Registration"** creates the farmer and the farm.

> 📷 **Screenshot 09** – Step 3 with area entry and unit selection.
>
> ![Farm information](screenshots/registrar-09-farm.png)

### After completing

- Farmer and farm are **stored locally** with the status **Pending** (waiting for QC).
- The photos stay on the device at first and go out with the next upload.
- A success message appears; the dashboard count then goes up by the new entries.
- While saving, an overlay shows the progress (including the photo upload percentage when uploads are active).

> ⚠️ **Cancelling:** If you leave the form after entering data, the app asks whether the data should be **discarded**. Discarded entries cannot be recovered.

> 📷 **Screenshot 10** – Progress overlay or success message after completion.
>
> ![Registration completed](screenshots/registrar-10-abschluss.png)

---

## 5. Workflow B: Record Field Boundary

### 5.1 Select a farm (mandatory)

A field **always belongs to a farm**, so the farm is selected first.

- If no farm has been recorded yet, **"No farms registered yet"** appears together with the **"Register Farm"** button – which leads straight into [workflow A](#4-workflow-a-register-farmfarmer).
- The selected farm is then shown in the top bar; the ✏️ icon lets you switch it (**"Change Farm"**).

> 📷 **Screenshot 11** – Farm selection before starting the recording.
>
> ![Farm selection](screenshots/registrar-11-farmauswahl.png)

### 5.2 Unfinished recordings

If there are **unfinished field recordings**, the app asks at start-up: **"Continue or start new?"** – either keep walking the area you began or tap **"Start new field"**.

### 5.3 Walking the boundary

The field boundary is walked point by point:

| Control | Function |
|---|---|
| **Add Point** | Take the current GPS position as a corner point |
| Point list / map | Shows the points set so far and the resulting area |
| Tap a point → **Delete Point?** | Remove a single misplaced point (with confirmation) |
| **Clear Polygon** | Reset the recording completely |
| Accuracy display | Current GPS accuracy in metres |

Rules when setting points:

- **At least 3 points** are required – otherwise "At least 3 points required".
- Two points must be **at least 5 m** apart – otherwise "Point too close to previous point".
- Before saving, the app asks whether the polygon should be **closed automatically** (last point back to the first). The calculated area is shown.
- With poor GPS accuracy (red display) it is better to wait a moment until the signal stabilises.

> 📷 **Screenshot 12** – Recording in progress: map with points set, point counter and accuracy display.
>
> ![Record field boundary](screenshots/registrar-12-polygon.png)

### 5.4 Field photo (mandatory)

The **Field Photo** is taken via the camera icon in the top bar. The icon carries a coloured marker:

| Marker | Meaning |
|---|---|
| 🟠 Warning sign | Photo still missing |
| 🟢 Check mark | Photo present and valid |
| 🔴 Cross | Photo invalid – it was taken **outside the polygon** |

The photo must be taken **inside the recorded area** (tolerance 50 m); it serves as proof that the registrar was actually on site.

> 📷 **Screenshot 13** – Field photo dialog with a valid (green) status.
>
> ![Field photo](screenshots/registrar-13-feldfoto.png)

### 5.5 Saving

**"Register Field"** creates the field and links it to the selected farm. This field also starts with the status **Pending**. Alternatively, the recording can be interrupted with **"Save and Exit"** and continued later.

---

## 6. History: reviewing and correcting your data

**Dashboard → "View History"** opens the complete registration history of this device.

What you can do:

- **Filter** by *All / Farmers / Farms / Fields* and **search** by name
- Inspect the **status** of each entry (verified / pending / rejected) with its registration date
- **Edit an entry**: correct master data, retake the ID or consent form photo
- **Add a farm to a farmer** (one farmer can have several farms)
- **Add a field to a farm** (one farm can have several fields)
- View the area and map extract of a field

> 📷 **Screenshot 14** – History with filter bar and several entries in different states.
>
> ![History](screenshots/registrar-14-verlauf.png)

> 📷 **Screenshot 15** – Detail / edit view of an entry.
>
> ![Edit entry](screenshots/registrar-15-eintrag-bearbeiten.png)

---

## 7. Working offline and uploading data

### 7.1 The principle

Data capture works **entirely without internet**. Every record is saved locally at once and placed in an upload queue. As soon as the device is online, the queue is processed:

- automatically about **every 10 minutes** while the dashboard is open and uploads are not paused,
- or immediately via **"Sync now"** in the sync panel.

### 7.2 The sync panel

Reachable via the **upload chip in the status strip** or via *Tools & settings*.

| Element | Meaning |
|---|---|
| **Pause uploads** (switch) | Off = "Uploads active". On = "Uploads paused - data is captured locally only" |
| List of waiting items | Exactly what is still queued, with type and reason |
| Last successful sync | Time or date |
| Next retry / last error | Only shown when an upload is stuck |
| **Sync now** | Starts the upload immediately |

> 📷 **Screenshot 16** – Sync panel with the pause switch and the list of open uploads.
>
> ![Sync panel](screenshots/registrar-16-sync-panel.png)

### 7.3 When should uploads be paused?

In remote areas with a **very weak mobile signal**, large photos block the upload and slow the work down. In that case:

1. turn **Pause uploads** on,
2. keep working normally throughout the day (everything is stored locally),
3. in the evening, on a good connection (e.g. office Wi-Fi), turn the switch off again and tap **"Sync now"**.

> ⚠️ While paused, the data exists **only on the device**. It is safe only after a successful upload – do not reset the device or uninstall the app while open uploads are shown.

---

## 8. Tools & settings

The collapsed section at the bottom of the dashboard contains:

| Setting | Meaning |
|---|---|
| **Area Unit** | Unit for displaying field size. The button on the right cycles through the units valid for the country. |
| **Sync section** | The same panel as in [chapter 7](#72-the-sync-panel): pause uploads, waiting items, last sync, sync now. |

> 📷 **Screenshot 17** – Expanded "Tools & settings" section.
>
> ![Tools and settings](screenshots/registrar-17-werkzeuge.png)

> ℹ️ **Note on the IHCafé producer directory:** the directory is deliberately **not** loaded onto registrar devices – the full data set is several megabytes in size. It is available only to the **registrar coordinator in the QC view (web app)**; matching a record to an IHCafé producer happens there.

---

## 9. What happens after the upload (quality control)

1. The registrar captures the data → status **Pending**.
2. The data is transferred to the cloud.
3. The **registrar coordinator** reviews it in the QC view: photos, location, plausibility of the entries, and where applicable a match against the IHCafé producer directory.
4. Result:
   - **Verified** – the record is approved and counts under "Verified" on the dashboard.
   - **Rejected** – the record appears as rejected in the history and has to be corrected.

Hence: **take sharp, complete photos** and write names carefully – every correction means a second visit to the farmer.

---

## 10. Messages and frequently asked questions

| Message / situation | Cause | Solution |
|---|---|---|
| "GPS must be enabled for registration" | Location service off or permission missing | Enable GPS on the device, grant the location permission to the app, then start again |
| ID photo / consent photo demanded | A mandatory photo is missing | Take the photo; only then can you move on |
| "At least 3 points required" | The polygon has too few corner points | Set more points along the field boundary |
| "Point too close to previous point (min 5m)" | Two points are too close together | Walk a bit further before setting the next point |
| Field photo marked red | The photo was taken outside the polygon | Stand inside the recorded area and retake the photo (tolerance 50 m) |
| "Field must be linked to a farm" | No farm selected | Select a farm, or register one first |
| "No farms registered yet" | No record exists for this farm yet | Use **"Register Farm"** to create the farmer and farm first |
| Chip permanently shows "*N* open" | No connection, uploads paused, or an upload error | Open the sync panel: turn pausing off, check the connection, read the error message, tap **"Sync now"** |
| Dashboard numbers look too low | The numbers only cover records on **this device** | This is normal; the overall view belongs to the registrar coordinator |
| An email address appears instead of a name | First/last name missing in the profile | Add the name via the profile icon and save |

---

## 11. Screenshot index

Place all images in `docs/screenshots/`. Recommended: portrait orientation, device width ≥ 1080 px, PNG. The German, English and Spanish handbooks reference the **same** file names – one screenshot set serves all three, or you can keep a separate set per language in subfolders and adjust the paths.

| No. | File name | Subject |
|---|---|---|
| 01 | `registrar-01-dashboard.png` | Complete dashboard after login |
| 02 | `registrar-02-profil.png` | "Edit Profile" dialog |
| 03 | `registrar-03-statusstreifen.png` | Status strip (GPS / online / uploads), preferably with open uploads |
| 04 | `registrar-04-gps-hinweis.png` | "GPS must be enabled for registration" dialog |
| 05 | `registrar-05-tagesleistung.png` | Daily card with numbers and "View History" |
| 06 | `registrar-06-stepper-uebersicht.png` | Registration stepper, three steps visible |
| 07 | `registrar-07-landwirt.png` | Step 1 with ID photo (green frame) |
| 08 | `registrar-08-einverstaendnis.png` | Step 2 with the photographed consent form |
| 09 | `registrar-09-farm.png` | Step 3 with area and unit selection |
| 10 | `registrar-10-abschluss.png` | Progress overlay or success message |
| 11 | `registrar-11-farmauswahl.png` | Farm selection in the field boundary recorder |
| 12 | `registrar-12-polygon.png` | Polygon recording in progress with points |
| 13 | `registrar-13-feldfoto.png` | Field photo dialog, valid status |
| 14 | `registrar-14-verlauf.png` | History with filters and entries |
| 15 | `registrar-15-eintrag-bearbeiten.png` | Detail / edit view of an entry |
| 16 | `registrar-16-sync-panel.png` | Sync panel with the pause switch |
| 17 | `registrar-17-werkzeuge.png` | Expanded "Tools & settings" section |
