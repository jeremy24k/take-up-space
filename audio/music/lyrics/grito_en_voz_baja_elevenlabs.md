# "Grito en voz baja": instrucciones para ElevenLabs Music

Registro de iteraciones. Cada versión anota qué se pegó y qué salió.

---

## Versión 0 (2026-11-23)

### 1. Prompt de estilo (pegar tal cual; en inglés, ElevenLabs lo entiende mejor)

```
Intimate acoustic folk-pop ballad sung in Spanish. A single steel-string acoustic guitar, gently fingerpicked, warm and close, like a street musician playing softly on a park bench at night. Slow tempo, around 76 BPM, 4/4, in a minor key that lifts slightly in the chorus.

Female vocal, young (early twenties), soft and breathy, almost whispered, recorded very close to the microphone, so you hear her breaths. She sounds shy and a little unsure, like someone who never sings in front of anyone, but the melody is clear and memorable. No vibrato, no belting, no runs: the vocal never gets loud, even in the chorus, which grows in feeling, not in volume.

No drums, no bass, no piano, no strings, no backing vocals, no harmonies, no reverb wash. Just one voice and one guitar, melancholic but warm and hopeful.

Structure: short guitar intro; verse; chorus; verse; chorus; then a bridge where the guitar stops completely and she sings alone, a cappella, with a short silence in the middle of the bridge; final outro where the guitar comes back softly and she hums the chorus melody with no words, fading out.
```

### 2. Letra (pegar en el campo de letra, con las marcas de sección)

```
[Intro]
(guitar only)

[Verse 1]
Siempre pido perdón por estar,
por respirar muy alto, por mirar.
Me hago pequeña en la esquina del salón,
por si mi sombra molesta al sol.

[Chorus]
Pero hoy voy a ocupar espacio,
un poquito, solo un poco de lugar.
No es que grite, no es que gane:
el mundo no se rompe si estoy.
Y si el ruido me empuja a esconder,
me quedo aquí, aunque no sepa qué hacer.

[Verse 2]
No es que odie a la gente, ya lo sé,
es que a veces mi voz no tiene fe.
Pero hay un mar de gente como yo,
que se esconde porque el miedo les habló.

[Chorus]
Pero hoy voy a ocupar espacio,
un poquito, solo un poco de lugar.
No es que grite, no es que gane:
el mundo no se rompe si estoy.
Y si el ruido me empuja a esconder,
me quedo aquí, aunque no sepa qué hacer.

[Bridge - a cappella, no guitar]
No soy un fantasma,
no soy un error,
solo estoy aprendiendo a estar.
(silence)
Y si ocupo un poquito de este aire,
quizás yo también pueda respirar.

[Outro - soft guitar, humming, no words]
Mmm... mmm...
```

### 3. Ajustes

- **Duración:** unos 2:45–3:00, o "Auto" si no se puede elegir.
- **Voz / instrumental:** con voz (vocals on).
- **Tandas:** generar 3 o 4 y escuchar todas antes de iterar.

### 4. Cómo elegir (lo que más importa, de más a menos)

1. **La voz de Alice:** ¿suena tímida, cercana, susurrada? Si suena a cantante segura o a diva, se descarta aunque lo demás esté bien.
2. **El puente sin guitarra:** ¿la guitarra se calla de verdad? Si no, se puede rescatar separando la voz, pero suena mejor si sale así de origen.
3. **El tarareo final:** ¿tararea la melodía del estribillo? Lo usaremos para la escena en la que Alice tararea con los auriculares.
4. **Pronunciación en español:** sin acento raro ni palabras cortadas, sobre todo en "ocupar espacio" (el chiste "despacio" depende de que se entienda bien).
5. **Que no haya instrumentos de más** (batería, piano, coros).

### Resultado de la versión 0
- Se generaron 2 (`Ocupar_Espacio_2026-11-23T234659.wav`, 3:10, y `(1)`, 2:40). No gustó ninguna.
- **Voz:** algo robótica, con acento de España.
- **Transiciones y rimas:** no funcionan; los versos de largo desigual se cantan apretados y el estribillo casi no rima.
- **Puente:** el volumen es plano en toda la canción, así que la guitarra no se paró.

---

## Versión 1 (2026-11-23)

Cambios respecto a la v0:
- **Voz:** de "casi susurro, sin vibrato" pasa a una voz suave y natural, de cantautora, con imperfecciones humanas. Restringir tanto la volvía robótica.
- **Acento:** se pide explícitamente español latinoamericano neutro, sin la "z" ni la "c" de España.
- **Puente:** se pide la guitarra muy bajita en vez de en silencio. El silencio total se consigue luego separando la voz.
- **Letra** (aprobado por el usuario):
  - Estrofa 1, línea 3: «Me hago pequeña en la esquina del salón» → «Me encojo en la esquina del salón».
  - Estribillo, línea 4: «el mundo no se rompe si estoy» → «el mundo no se rompe por estar». Así rima con «lugar» y repite el «por estar» de la estrofa 1.

### 1. Prompt de estilo

```
Intimate acoustic singer-songwriter ballad, sung in Spanish with a neutral Latin American accent (seseo; no Castilian Spanish pronunciation, no lisped "z" or "c"). A single acoustic guitar, gently fingerpicked, warm, natural room sound, like a home recording or a street musician playing softly on a park bench at night. Slow tempo, about 76 BPM, minor key that opens up warmly in the chorus.

Female vocal in her early twenties: soft, gentle and natural, a real human singer-songwriter performance with small imperfections, audible breaths and a light, natural vibrato at the ends of phrases. She sounds shy and vulnerable, singing for one person, never belting or showing off. The chorus grows in emotion, not in volume. Clear, relaxed Spanish diction, each phrase given room to breathe.

No drums, no bass, no piano, no strings, no backing vocals, no harmonies. One voice and one guitar. Melancholic but warm and hopeful.

Structure: short guitar intro; verse; chorus; verse; chorus; a bridge where the guitar drops to very soft, sparse notes so the voice is almost alone; a final outro where she hums the chorus melody softly with no words over the guitar, fading out.
```

### 2. Letra

```
[Intro]
(guitar only)

[Verse 1]
Siempre pido perdón por estar,
por respirar muy alto, por mirar.
Me encojo en la esquina del salón,
por si mi sombra molesta al sol.

[Chorus]
Pero hoy voy a ocupar espacio,
un poquito, solo un poco de lugar.
No es que grite, no es que gane:
el mundo no se rompe por estar.
Y si el ruido me empuja a esconder,
me quedo aquí, aunque no sepa qué hacer.

[Verse 2]
No es que odie a la gente, ya lo sé,
es que a veces mi voz no tiene fe.
Pero hay un mar de gente como yo,
que se esconde porque el miedo les habló.

[Chorus]
Pero hoy voy a ocupar espacio,
un poquito, solo un poco de lugar.
No es que grite, no es que gane:
el mundo no se rompe por estar.
Y si el ruido me empuja a esconder,
me quedo aquí, aunque no sepa qué hacer.

[Bridge - very soft guitar, voice almost alone]
No soy un fantasma,
no soy un error,
solo estoy aprendiendo a estar.
Y si ocupo un poquito de este aire,
quizás yo también pueda respirar.

[Outro - soft humming, no words]
Mmm... mmm...
```

### 3. Ajustes
- Duración: unos 2:45 (o "Auto").
- Con voz.
- Generar 3 o 4.
- Si la interfaz deja editar por secciones (duración o estilo de cada una), alargar un poco el puente y marcarlo como "soft / sparse".

### Resultado de la versión 1
- El usuario hizo varias tandas. La que más le gustó: `Ocupar_Espacio_2026-11-24T000222.wav` (3:00, 48 kHz estéreo, −17,2 LUFS). Le gustó sobre todo cómo está planteado el **estribillo**, pero no es la definitiva: hay cosas que no le convencen y quiere seguir probando.
- Lo aprendido (del usuario): **marcar entre paréntesis en la letra el rol, la intensidad, el tono y las pausas mejora mucho la generación.** Ejemplo: «(Estrofa 1 — Alice sola, voz suave y contenida)», «(Pausa corta)», «(Susurrado)». La letra con la que lo ejemplificó era solo de prueba; la oficial sigue siendo la de `cancion_clara_es.md`.
- Análisis de esa tanda: la voz entra hacia el segundo 17. Hay cambios de sección en torno a 40 s, 120 s y 145 s. Entre 145 y 172 s el agudo baja (sección más suave, probablemente el puente). Final en fundido hacia 175 s.

---

## Versión 2 (2026-11-24)

Cambios respecto a la v1:
- La **misma letra oficial**, ahora con **acotaciones entre paréntesis** en cada sección y dentro de los versos: quién canta, intensidad, tono y pausas.
- El prompt de estilo es el de la v1, más corto: las acotaciones de la letra hacen ahora parte del trabajo.

### 1. Prompt de estilo

```
Intimate acoustic singer-songwriter ballad in Spanish, neutral Latin American accent (seseo, no Castilian pronunciation). One fingerpicked acoustic guitar, warm natural room sound, like a street musician playing softly on a park bench at night. Slow, about 76 BPM, minor key that opens up warmly in the chorus. Young female vocal: soft, natural and human, shy and vulnerable, small imperfections and audible breaths, light vibrato only at phrase ends; she never belts. No drums, bass, piano, strings or backing vocals. Melancholic but warm and hopeful.
```

### 2. Letra con acotaciones

```
(Intro — solo la guitarra de Clara, suave, unos compases)

(Estrofa 1 — Alice sola, casi en voz baja, contenida, como si cantara para sí misma)
Siempre pido perdón por estar,
por respirar muy alto, por mirar.
Me encojo en la esquina del salón,
por si mi sombra molesta al sol.

(Estribillo — la voz se abre un poco, más cálida, sin subir el volumen)
Pero hoy voy a ocupar espacio,
un poquito, solo un poco de lugar.
No es que grite, no es que gane:
el mundo no se rompe por estar.
Y si el ruido me empuja a esconder,
me quedo aquí, aunque no sepa qué hacer.

(Estrofa 2 — vuelve a ser íntima, un poco más segura que la primera)
No es que odie a la gente, ya lo sé,
es que a veces mi voz no tiene fe.
Pero hay un mar de gente como yo,
que se esconde porque el miedo les habló.

(Estribillo — igual que antes, con un poco más de convicción)
Pero hoy voy a ocupar espacio,
un poquito, solo un poco de lugar.
No es que grite, no es que gane:
el mundo no se rompe por estar.
Y si el ruido me empuja a esconder,
me quedo aquí, aunque no sepa qué hacer.

(Puente — la guitarra se detiene; silencio casi total, solo la voz de Alice, frágil y muy cerca)
No soy un fantasma,
no soy un error,
solo estoy aprendiendo a estar.
(Pausa larga, solo su respiración)
Y si ocupo un poquito de este aire,
quizás yo también pueda respirar.

(Final — vuelve la guitarra muy suave; Alice tararea la melodía del estribillo sin letra, apagándose)
(Tarareo) Mmm... mmm...
```

### 3. Ajustes
- Duración: unos 2:45 (o "Auto"). Con voz. Generar 3 o 4.

### Resultado de la versión 2
(pendiente)
