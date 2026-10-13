// Ajustes nativos de Rincón Futbolero. Se ejecuta DESPUÉS de "npx cap sync android".
// Es seguro repetirlo: si algo ya está aplicado, no lo vuelve a tocar.
import fs from 'node:fs';
import path from 'node:path';

const root = process.argv[2] || 'android';
const log = (m) => console.log('• ' + m);
const leer = (f) => (fs.existsSync(f) ? fs.readFileSync(f, 'utf8') : null);

// 1) Barra de estado y de navegación con los colores de la app
const styles = path.join(root, 'app/src/main/res/values/styles.xml');
let st = leer(styles);
if (st === null) log('No se encontró styles.xml (se omite el color de barras).');
else if (st.includes('android:statusBarColor')) log('Barras: ya estaban aplicadas.');
else {
  const re = /(<style\s+name="AppTheme\.NoActionBar"[^>]*>)([\s\S]*?)(<\/style>)/;
  if (!re.test(st)) log('No se encontró el tema AppTheme.NoActionBar (se omite).');
  else {
    st = st.replace(re, (_, a, b, c) =>
      a + b +
      '\n        <item name="android:statusBarColor">#050A07</item>' +
      '\n        <item name="android:navigationBarColor">#06100A</item>' +
      '\n        <item name="android:windowLightStatusBar">false</item>' +
      '\n        <item name="android:windowLightNavigationBar">false</item>\n    ' + c);
    fs.writeFileSync(styles, st);
    log('Barras de estado y navegación: color de la app.');
  }
}

// 2) Firma "release" con llave propia (usa variables de entorno)
const gradle = path.join(root, 'app/build.gradle');
let g = leer(gradle);
if (g === null) log('No se encontró app/build.gradle (se omite la firma).');
else if (g.includes('signingConfigs')) log('Firma: ya estaba aplicada.');
else {
  const bloque =
`    signingConfigs {
        release {
            def ks = System.getenv("KEYSTORE_FILE")
            if (ks) {
                storeFile file(ks)
                storePassword System.getenv("KEYSTORE_PASSWORD")
                keyAlias System.getenv("KEY_ALIAS")
                keyPassword System.getenv("KEY_PASSWORD")
            }
        }
    }
`;
  if (!/\n\s*buildTypes\s*\{/.test(g)) log('No se encontró buildTypes (se omite la firma).');
  else {
    g = g.replace(/\n(\s*)buildTypes\s*\{/, (m) => '\n' + bloque + m.slice(1));
    g = g.replace(/(buildTypes\s*\{\s*release\s*\{)/, '$1\n            signingConfig signingConfigs.release');
    fs.writeFileSync(gradle, g);
    log('Firma release configurada (llave por variables de entorno).');
  }
}
