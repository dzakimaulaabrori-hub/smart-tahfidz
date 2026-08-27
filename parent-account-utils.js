const fs = require('fs');
const path = require('path');
const XLSX = require('xlsx');

const DEFAULT_FILE = path.join(__dirname, 'data-orang-tua.xlsx');

function readParentRows(filePath = DEFAULT_FILE) {
  if (!fs.existsSync(filePath)) throw new Error(`File Excel tidak ditemukan: ${filePath}`);
  const workbook = XLSX.readFile(filePath);
  const sheetName = workbook.SheetNames.includes('Data Orang Tua') ? 'Data Orang Tua' : workbook.SheetNames[0];
  if (!sheetName) throw new Error('Workbook tidak memiliki sheet.');
  const sheet = workbook.Sheets[sheetName];
  const matrix = XLSX.utils.sheet_to_json(sheet, { header: 1, defval: '' });
  const headers = (matrix[0] || []).map(value => String(value).trim().toLowerCase());
  const dataRows = XLSX.utils.sheet_to_json(sheet, { defval: '' });

  // The supplied file has an "email" header, but its values are parent names.
  // Keep the source file untouched and explicitly interpret that legacy column.
  const nameHeader = headers.find(h => ['nama', 'nama_orang_tua', 'nama orang tua', 'orang tua'].includes(h));
  const valueHeader = nameHeader || (headers.includes('email') ? 'email' : null);
  const nisHeader = headers.find(h => ['nis', 'nis_anak', 'nis anak'].includes(h));
  if (!valueHeader || !nisHeader) throw new Error('Kolom nama orang tua dan NIS tidak ditemukan.');

  const rows = dataRows.map((row, index) => ({
    excelRow: index + 2,
    nama: String(row[valueHeader] ?? '').trim(),
    nis: String(row[nisHeader] ?? '').trim(),
    hubungan: String(row.hubungan ?? 'ayah').trim().toLowerCase() || 'ayah',
  }));
  return { filePath, workbook, sheetName, headers, rows, sourceNameHeader: valueHeader };
}

function readGeneratedRows(filePath) {
  if (!fs.existsSync(filePath)) throw new Error(`File generated tidak ditemukan: ${filePath}`);
  const workbook = XLSX.readFile(filePath);
  const sheetName = workbook.SheetNames.includes('Data Orang Tua') ? 'Data Orang Tua' : workbook.SheetNames[0];
  const rows = XLSX.utils.sheet_to_json(workbook.Sheets[sheetName], { defval: '' });
  const required = ['nama_orang_tua', 'email', 'nis_anak', 'hubungan', 'password_awal'];
  const headers = (XLSX.utils.sheet_to_json(workbook.Sheets[sheetName], { header: 1, defval: '' })[0] || []).map(value => String(value));
  if (required.some(header => !headers.includes(header))) throw new Error(`File generated harus memiliki kolom: ${required.join(', ')}.`);
  return rows.map((row, index) => ({
    excelRow: index + 2,
    nama: String(row.nama_orang_tua ?? '').trim(),
    email: String(row.email ?? '').trim().toLowerCase(),
    nis: String(row.nis_anak ?? '').trim(),
    hubungan: String(row.hubungan ?? 'ayah').trim().toLowerCase() || 'ayah',
    password: String(row.password_awal ?? ''),
  }));
}

function normalizeName(value) {
  return String(value || '').trim().replace(/\s+/g, ' ');
}
function emailPart(value) {
  return normalizeName(value).split(' ')[0].normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]/g, '');
}
function fullNamePart(value) {
  return normalizeName(value).normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '');
}

function generateEmails(rows, existingEmails = new Set()) {
  // Existing email is intentionally not treated as unavailable: the create
  // script must be able to reuse an existing orang_tua account. Only emails
  // generated earlier in this same file are reserved here.
  const generated = new Set();
  return rows.map(row => {
    const first = emailPart(row.nama);
    const full = fullNamePart(row.nama);
    const base = first || 'orangtua';
    const candidates = [
      `${base}@gmail.com`,
      `${base}.${row.nis}@gmail.com`,
      `${full || base}.${row.nis}@gmail.com`,
    ];
    let email = candidates.find(candidate => !generated.has(candidate));
    if (!email) {
      let counter = 2;
      do { email = `${full || base}.${row.nis}.${counter}@gmail.com`; counter++; }
      while (generated.has(email));
    }
    generated.add(email);
    return { ...row, email, emailConflict: email !== candidates[0] };
  });
}

module.exports = { DEFAULT_FILE, readParentRows, readGeneratedRows, generateEmails, normalizeName };
