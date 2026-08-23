# 📋 AUDIT UI/UX - TAHFIDZUNA
**Tanggal:** 17 Agustus 2026  
**Status:** Audit Awal - Persiapan Redesign  
**Tujuan:** Mengidentifikasi struktur UI saat ini sebelum redesign

---

## 1. STRUKTUR UI SAAT INI

### 1.1 Layout Utama
- **Single Page Application (SPA)** dengan vanilla JavaScript
- **Dua layout utama:**
  - **#gate** - Login/authentication screen
  - **#app** - Dashboard setelah login (flex container)

### 1.2 Komponen Utama

#### **Login Screen (#gate)**
- `.gate-card` - Card form login (max-width: 390px)
- `.lamp-scene` - Full-screen animasi login lampu (overlay)
  - `.lamp-wrapper` - SVG lampu
  - `.lamp-hint-dark` - Hint text "Tarik tali lampu untuk masuk"
  - `.lamp-card` - Form login dalam animasi lampu (opacity animation)

#### **Dashboard (#app)**
- `.mobile-topbar` - Header mobile (fixed, height 56px)
  - Logo icon (26x26px) + menu hamburger
  - Responsive hanya di mobile (display:none default, tampil @768px ke bawah)
  
- `.sidebar` - Navigasi utama
  - Width: 238px (desktop), 220px (tablet), 250px (mobile)
  - Fixed/sticky positioning
  - Mobile: transform translateX -104% (slide-out drawer)
  
- `.main` - Content area
  - Flex: 1
  - Responsive padding: 40px 48px (desktop) → 20px 16px (mobile)
  - Max-width: 1120px (desktop)

### 1.3 Struktur Halaman (Role-based)
```
Setiap role punya navigasi berbeda:
- admin: ringkasan, siswa, kelas, indikator, relasi, presensi
- wali_kelas: ringkasan, karakter, absensi, riwayat, quran
- guru_quran: ringkasan, tilawah, tahsin, tahfidz, approval, riwayat
- kepala_sekolah: ringkasan, quran, karakter
- orang_tua: quran, lapor, karakter, absensi
```

---

## 2. LOKASI BRANDING / LOGO

### 2.1 Logo Visual (Icon)
**Format:** Base64 encoded PNG (78KB)  
**Lokasi di HTML:**

1. **Login Card** (`#gateLogin`)
   - Line ~419: `<img src="data:image/png;base64,..." class="logo-icon-lg" alt="Tahfidzuna">`
   - Size: `.logo-icon-lg` = 56x56px (desktop), clamp(44px, 12vw, 56px)
   - Styling: border-radius 14px, box-shadow

2. **Mobile Topbar** (`#mobileTopbar`)
   - Line ~441: `<img src="data:image/png;base64,..." class="logo-icon">`
   - Size: `.logo-icon` = 26x26px (responsive, width: 26px)
   - Styling: border-radius 6px

3. **Sidebar** (`#appSidebar`)
   - Line ~446: `<img src="data:image/png;base64,..." class="logo-icon">`
   - Size: `.logo-icon` = 32x32px (desktop), 26x26px (mobile)
   - Styling: border-radius 8px
   - Container: `.logo-brand` (display: flex, gap: 10px)

### 2.2 Text Logo
**"Tahfidzuna"** - Newsreader serif font

1. **Login Card** (`#gateLogin`)
   - Line ~419: `<div class="logo" style="text-align:center;">Tahfidzuna</div>`
   - Styling: 
     - `.logo`: font-size clamp(25px, 5vw, 29px), font-weight 600, color var(--primary)
   - Alt text untuk gambar: `alt="Tahfidzuna"`

2. **Subtitle di Login**
   - Line ~420: `<div style="...">SD Al Irsyad — Penilaian Al-Qur'an & Karakter</div>`
   - Font-size: 12.5px, color: var(--ink-soft)

3. **Sidebar** 
   - Logo text tidak terlihat di HTML (hanya icon)
   - Role label di `.logo-sub`: "PANEL ADMIN", "PANEL WALI KELAS", dll

### 2.3 CSS Classes untuk Logo
```css
.logo-brand {
  display: flex;
  align-items: center;
  gap: 10px;
}
.logo-icon {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  flex-shrink: 0;
  display: block;
  box-shadow: var(--shadow-sm);
}
.logo-icon-lg {
  width: 56px;
  height: 56px;
  border-radius: 14px;
  margin: 0 auto 12px;
  box-shadow: var(--shadow-md);
}
.logo {
  font-family: 'Newsreader', serif;
  font-size: 29px;
  font-weight: 600;
  color: var(--primary);
  letter-spacing: -.01em;
}
```

---

## 3. LOKASI ANIMASI LAMPU (LAMP)

### 3.1 HTML Elements
```html
<!-- Full-screen overlay container -->
<div class="lamp-scene" id="lampScene" style="display:none;">
  
  <!-- SVG Lampu -->
  <div class="lamp-wrapper" id="lampWrapper">
    <svg class="lamp-svg" viewBox="0 0 200 220" xmlns="http://www.w3.org/2000/svg">
      <!-- Inner glow -->
      <ellipse class="inner-glow" cx="100" cy="72" rx="55" ry="26" />
      
      <!-- Lamp base (tiang) -->
      <rect class="lamp-base-part" x="94" y="64" width="12" height="72" rx="6" />
      
      <!-- Pull cord (tali) -->
      <g class="pull-cord">
        <line class="cord-line" x1="128" y1="72" x2="128" y2="122" />
        <circle class="cord-bead" cx="128" cy="130" r="6" />
        <circle class="cord-hit" id="lampCordHit" cx="128" cy="130" r="24" fill="transparent" />
      </g>
      
      <!-- Lamp shade (kap lampu) -->
      <path class="lamp-shade" d="M35 72 C 35 25, 165 25, 165 72 C 165 85, 35 85, 35 72 Z" />
    </svg>
  </div>
  
  <!-- Hint text: "Tarik tali lampu untuk masuk ↓" -->
  <div class="lamp-hint-dark" id="lampHintDark">Tarik tali lampu untuk masuk &darr;</div>

  <!-- Login form (berubah opacity saat lampu nyala) -->
  <div class="gate-card lamp-card" id="gateLogin">
    <!-- Form content -->
  </div>
</div>
```

### 3.2 CSS Animasi Lampu
**Lokasi:** Dalam `<style>` tag (banyak rules)

#### **Kondisi 0: Lampu MATI (default)**
```css
.lamp-scene {
  background-color: #090D0B;  /* Gelap */
  transition: background-color .75s cubic-bezier(.4, 0, .2, 1);
}
.lamp-shade { fill: #4B463C; filter: brightness(.72); }
.lamp-base-part { fill: #27251F; }
.inner-glow { opacity: .04; filter: blur(9px); }
.cord-line { stroke: #665E4F; }
.lamp-wrapper { transform: translateX(0) scale(1); }
.lamp-hint-dark { opacity: .8; color: #B8B0A0; }
.lamp-card { opacity: 0; transform: translateY(18px) scale(.97); pointer-events: none; }
```

#### **Kondisi 1: Lampu NYALA (class .lamp-on)**
```css
.lamp-scene.lamp-on {
  background-color: var(--bg);  /* Terang */
}
.lamp-shade { 
  fill: #EFE0BC; 
  filter: drop-shadow(0 0 12px rgba(230, 180, 90, .42));
}
.lamp-base-part { fill: #A8926F; }
.inner-glow { opacity: .58; filter: blur(10px); }
.cord-line { stroke: #9A8563; }
.lamp-wrapper { 
  transform: translateX(clamp(-280px, -22vw, -140px)) 
             translateY(clamp(-150px, -16vh, -72px)) 
             scale(.72);
}
.lamp-hint-dark { opacity: 0; transform: translateY(8px); pointer-events: none; }
.lamp-card { opacity: 1; transform: translateY(0) scale(1); pointer-events: auto; }
```

### 3.3 Timing & Transitions
**Fase transisi berlapis (staged illumination):**

1. **Background fade:** .72s dengan delay .12s
2. **Ambient glow fade:** .62s dengan delay .28s  
3. **Lamp wrapper move:** .78s dengan delay .14s
4. **Shade fill:** .38s dengan delay .12s
5. **Inner glow opacity:** .52s dengan delay .24s
6. **Login card appear:** .52s opacity + .68s transform dengan delay .54s

**Cubic-bezier curves:** `.22, .8, .26, 1` (ease-out-back effect)

### 3.4 JavaScript untuk Animasi
```javascript
// Toggle lamp-on class saat cord diklik
document.getElementById('lampCordHit').addEventListener('click', () => {
  document.getElementById('lampScene').classList.toggle('lamp-on');
});
```

### 3.5 Responsive Adjustments untuk Lampu
**@768px ke bawah (mobile):**
```css
.lamp-scene {
  grid-template-columns: minmax(0, 1fr);  /* Single column */
  grid-template-rows: auto auto auto;
}
.lamp-wrapper {
  transform: translateX(clamp(-38px, -8vw, -12px)) 
             translateY(-4px) 
             scale(.62);
}
.lamp-svg { width: 130px; }
```

**@1024px+ with height constraint:**
```css
.lamp-svg { width: 150px; }
.lamp-card { max-height: calc(100dvh - 48px); overflow-y: auto; }
```

---

## 4. BREAKPOINTS RESPONSIVE

### 4.1 Media Query Breakpoints
```
1. @media (max-width: 480px)     → Mobile kecil
2. @media (max-width: 767px)     → Mobile ke tablet
3. @media (min-width: 768px)     → Tablet naik
4. @media (min-width: 900px)     → Desktop refinement
5. @media (min-width: 1024px)    → Desktop besar
6. @media (min-width: 768px) and (max-width: 1023px) → Tablet spesifik
7. @media (min-width: 768px) and (max-height: 760px) → Landscape/short screen
```

### 4.2 Layout Changes per Breakpoint

| Breakpoint | Sidebar | Main | Mobile Topbar | Grid |
|---|---|---|---|---|
| **Desktop (>1024px)** | 238px, sticky | max-width 1120px, padding 40px 48px | hidden | 3-4 cols |
| **Tablet (768-1023px)** | 220px, padding 24px 16px | max-width 100%, padding 30px 24px | hidden | 2 cols |
| **Mobile (<768px)** | 250px, fixed, translate-out | padding 20px 16px, no max-width | 56px fixed | 2 cols → 1 col |
| **Small Mobile (<480px)** | (same) | (same) | (same) | 1 col |

### 4.3 Spacing Adjustments
```
Font sizes menggunakan clamp() untuk fluiditas:
- Logo text: clamp(25px, 5vw, 29px)
- Page heading: clamp(18px, ..., 27px)
- Padding main: clamp(20px, 4vw, 48px)
- Gap grid: 18px (desktop) → 10px (mobile)
```

---

## 5. MASALAH UI/UX YANG DITEMUKAN

### 5.1 Mobile Experience
- ⚠️ **Sidebar drawer** transformasi tapi bisa lebih smooth dengan animation-end event
- ⚠️ **Table overflow** pada mobile - ada horizontal scroll tapi bisa lebih baik
- ⚠️ **Form inputs** min-height 44px tapi spacing bisa lebih konsisten
- ⚠️ **Typography scaling** menggunakan clamp() yang baik, tapi bisa lebih presisi

### 5.2 Desktop Experience
- ⚠️ **Sidebar width 238px** agak sempit untuk typography panjang
- ⚠️ **Lamp animation** kompleks dengan banyak timing delay - bisa overwhelming
- ⚠️ **Z-index stacking** ada 5+ layer (#gate 200, lamp 201, sidebar 180, overlay 170) - perlu audit
- ✅ **Color scheme** konsisten dan baik

### 5.3 Animasi Lampu Saat Ini
- ⚠️ **Staged timing** dengan 6+ delays berbeda membuat flow kurang intuitif
- ⚠️ **Easing curves** semua pakai cubic-bezier custom - perlu dokumentasi
- ⚠️ **SVG complexity** ada 5 elemen yang di-animate (shade, base, glow, cord, wrapper)
- ⚠️ **Transformation stacking** rotate + scale + translate bisa menyebabkan performance issue di mobile lama

### 5.4 Branding
- ⚠️ **Logo hanya base64** - tidak ada asset terpisah, sulit di-maintain
- ⚠️ **Logo sizing** menggunakan clamp() tapi consistency di berbagai resolusi perlu cek
- ⚠️ **Alt text** ada tapi tidak informatif ("Tahfidzuna" saja)
- ⚠️ **Subtitle "SD Al Irsyad"** hanya ada di login, tidak konsisten di tempat lain

### 5.5 Accessibility
- ✅ **Focus visible** ada (:focus-visible)
- ✅ **Color contrast** cukup baik (primary #153A2E vs white)
- ⚠️ **Mobile hamburger** aria-label ada tapi bisa lebih deskriptif
- ⚠️ **Lamp animation** tidak ada pause/stop button untuk user yang prefer reduced motion

---

## 6. COLOR PALETTE & DESIGN TOKENS

### 6.1 CSS Variables yang Digunakan
```css
:root {
  /* Primary colors */
  --primary: #153A2E;
  --primary-light: #2B6350;
  --primary-dark: #0E2921;
  
  /* Accent colors */
  --accent: #B6842A;
  --accent-soft: #F1E3BE;
  --accent-deep: #8A6118;
  
  /* Neutral */
  --bg: #F5F2E7;
  --surface: #FFFFFF;
  --ink: #1A211C;
  --ink-soft: #5F6B61;
  
  /* Status */
  --good: #2B6350;
  --good-soft: #DEEBE4;
  --danger: #A63F29;
  --danger-soft: #F7E3DD;
  
  /* Borders */
  --border: #E4DFCB;
  --border-soft: #EDE9D9;
  
  /* Shadows */
  --shadow-sm: 0 1px 2px rgba(20, 30, 24, .05);
  --shadow-md: 0 4px 16px rgba(20, 30, 24, .07), ...;
  --shadow-lg: 0 16px 40px rgba(20, 30, 24, .12), ...;
  
  /* Radius */
  --radius: 14px;
}
```

**Theme:** Warm earth tones, Islamic geometric aesthetic (lattice pattern di sidebar)

---

## 7. RENCANA PERUBAHAN YANG AMAN

### 7.1 Tahap 1: Logo/Branding Replacement
**AMAN untuk:**
- ✅ Replace base64 logo dengan image baru di 3 lokasi (login, topbar, sidebar)
- ✅ Update alt text image
- ✅ Adjust sizing jika perlu (logo-icon, logo-icon-lg classes)
- ✅ Update `<title>` dan subtitle teks
- ✅ Tidak memodifikasi CSS layout

**JANGAN:**
- ❌ Ubah class names (logo-icon, logo-icon-lg, logo-brand)
- ❌ Ubah dimensions terlalu jauh (akan break responsive)
- ❌ Ubah ID element

### 7.2 Tahap 2: Animasi Lampu Removal/Simplification
**AMAN untuk:**
- ✅ Hide `.lamp-scene` dengan `display: none` saja
- ✅ Show `.lamp-card` langsung tanpa animasi (set opacity 1, transform none)
- ✅ Simplify gate-card styling
- ✅ Remove `.lamp-hint-dark` dari DOM atau hide dengan CSS
- ✅ Keep lampCordHit event listener (walaupun tidak function)

**JANGAN:**
- ❌ Hapus HTML element (lampCordHit, lampWrapper, dll) - keep for future
- ❌ Delete CSS classes - mark dengan comment `/\* deprecated \*/`
- ❌ Change JavaScript logic (checkAccess, showGateCard functions)

### 7.3 Tahap 3: Layout Responsive Refinement
**AMAN untuk:**
- ✅ Adjust padding/margin di breakpoints (main, card, form)
- ✅ Improve table horizontal scroll UX
- ✅ Enhance typography on mobile
- ✅ Adjust sidebar width dalam reasonable range (200-250px)
- ✅ Add new media queries untuk edge cases

**JANGAN:**
- ❌ Ubah flex/grid structure fundamental
- ❌ Hapus breakpoints yang ada
- ❌ Change .sidebar/.main flex ratio
- ❌ Ubah z-index layering logic

### 7.4 Tahap 4: Color & Theme Adjustments
**AMAN untuk:**
- ✅ Modify CSS variable values (--primary, --accent, etc)
- ✅ Add new token variables
- ✅ Update shadow definitions
- ✅ Adjust border-radius nilai global
- ✅ Add gradient overlays atau pattern baru

**JANGAN:**
- ❌ Change variable names (akan break CSS yang refer ke variable)
- ❌ Remove existing variables
- ❌ Hardcode colors dalam CSS (always use variables)

---

## 8. STRUKTUR FOLDER & FILES

```
/Tiilmidz
  ├── index.html              (SINGLE FILE - semua HTML + CSS + JS)
  ├── index backup.html       (Backup)
  ├── package.json            (Dependencies: Supabase, XLSX, Chart.js)
  ├── prisma/
  │   └── schema.prisma       (Database schema)
  ├── create-accounts.js      (Bulk account creation script)
  └── [config files]
```

**Catatan:** Aplikasi adalah **Single Page Application (SPA)** dalam 1 file HTML.  
Semua styling inline dalam `<style>` tag, semua logic dalam `<script>` tag.

---

## 9. DEPENDENCIES & EXTERNAL RESOURCES

### 9.1 CSS
- **Google Fonts:** Newsreader (serif), Inter (sans-serif), JetBrains Mono (mono)
- **Inline CSS:** Semua dalam `<style>` tag di index.html

### 9.2 JavaScript Libraries
```
- Supabase JS v2.45.4 (Authentication + Database)
- Chart.js v4.4.1 (Dashboard charts)
- XLSX v0.18.5 (Excel import/export)
```

### 9.3 External APIs
- **Supabase:** xjscbtaxrcqajpqzyysf.supabase.co
- **Auth Key:** sb_publishable_Odl4ZJ2NNZVxmrbywGdwBA_O-129oLE

---

## 10. VERIFIKASI SEBELUM REDESIGN

### ✅ Audit Completion Checklist
- [x] Struktur HTML dipetakan
- [x] Semua logo location diidentifikasi (3 tempat)
- [x] Animasi lampu CSS dikatalogue (50+ rules)
- [x] Breakpoint responsive didokumentasi (7 breakpoint)
- [x] Issues UI/UX didaftar
- [x] Design tokens di-export (CSS variables)
- [x] Dependencies dicatat
- [x] Safe change zones didefinisikan

### 📌 Siap untuk Tahap Redesign
**Zona Aman untuk Modifikasi:**
1. ✅ Logo/branding elements (HTML content)
2. ✅ Animation keyframes & CSS classes (mark as deprecated)
3. ✅ Color values (CSS variables)
4. ✅ Responsive breakpoints (values, not structure)
5. ✅ Typography sizing (in reasonable limits)

**Zona JANGAN Sentuh:**
1. ❌ Database queries & Supabase logic
2. ❌ Authentication flow
3. ❌ Element ID dan class structure
4. ❌ Form submission logic
5. ❌ Navigation/routing logic
6. ❌ Chart.js configuration (if keeping)

---

## KESIMPULAN

**Tahfidzuna** adalah aplikasi modern dengan:
- ✅ Responsive design yang solid
- ✅ Role-based UI yang comprehensive
- ✅ Islamic-inspired color palette & aesthetics
- ✅ Functional animasi (lampu) tapi bisa disederhanakan
- ✅ Good accessibility foundation

**Untuk redesign UI/UX:**
- Fokus pada branding replacement (logo di 3 lokasi)
- Simplify animasi lampu atau ganti dengan sesuatu yang lebih sederhana
- Improve mobile table UX
- Maintain semua ID/class untuk compatibility
- Keep database & auth logic untouched

**Status:** Siap untuk fase redesign! 🚀

---

**Audit Selesai** - Laporan ini dihasilkan tanpa modifikasi file apapun.  
Selanjutnya: Siap menunggu briefing redesign dari tim.
