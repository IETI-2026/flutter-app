# CameYo

Plataforma móvil de servicios bajo demanda desarrollada en Flutter. Conecta clientes con profesionales para solicitar, gestionar y dar seguimiento a servicios domésticos y técnicos.

## Tabla de contenidos

- [CameYo](#cameyo)
  - [Tabla de contenidos](#tabla-de-contenidos)
  - [Resumen](#resumen)
  - [Alcance funcional](#alcance-funcional)
  - [Arquitectura](#arquitectura)
  - [Stack tecnológico](#stack-tecnológico)
  - [Requisitos](#requisitos)
  - [Configuración de entorno](#configuración-de-entorno)
    - [1) Crear archivo local](#1-crear-archivo-local)
    - [2) Ajustar valores](#2-ajustar-valores)
    - [3) Ejecutar con variables](#3-ejecutar-con-variables)
  - [Ejecución local](#ejecución-local)
  - [Calidad y pruebas](#calidad-y-pruebas)
  - [Estructura del proyecto](#estructura-del-proyecto)
  - [Convenciones de desarrollo](#convenciones-de-desarrollo)
  - [Solución de problemas comunes](#solución-de-problemas-comunes)
  - [Roadmap recomendado para el README](#roadmap-recomendado-para-el-readme)
  - [Licencia y contexto académico](#licencia-y-contexto-académico)

## Resumen

El proyecto implementa una aplicación multiplataforma con enfoque en mantenibilidad, separación de responsabilidades y escalabilidad. Está orientado a un flujo de contratación de servicios con autenticación, manejo de roles y comunicación con backend mediante API REST.

## Alcance funcional

- Autenticación con correo y contraseña.
- Inicio de sesión con Google.
- Gestión de roles de usuario (cliente y profesional).
- Arquitectura limpia con separación por capas.
- Gestión de estado con BLoC.
- Integración con servicios de ubicación, multimedia y comunicación en tiempo real.

## Arquitectura

La solución sigue Clean Architecture y divide responsabilidades en capas:

- Presentation: interfaces de usuario, widgets, páginas y BLoC/Cubit.
- Domain: reglas de negocio, entidades y casos de uso.
- Data: modelos, repositorios e implementación de fuentes de datos.
- Core: configuración compartida, constantes, servicios transversales y utilidades.

Principios aplicados:

- Bajo acoplamiento entre capas.
- Inversión de dependencias con get_it.
- Trazabilidad y observabilidad mediante servicios centrales.

## Stack tecnológico

Versiones principales obtenidas desde pubspec del proyecto:

- Flutter SDK: 3.10.7+
- Dart SDK: ^3.10.7
- flutter_bloc: ^8.1.3
- dio: ^5.4.0
- get_it: ^7.6.4
- dartz: ^0.10.1
- google_sign_in: ^6.1.5
- shared_preferences: ^2.2.2
- geolocator: ^13.0.1
- socket_io_client: ^2.0.3+1

## Requisitos

Antes de ejecutar la app:

- Flutter SDK instalado y en PATH.
- Dispositivo Android/iOS, emulador o simulador configurado.
- Backend NestJS disponible y accesible desde el dispositivo.
- Credenciales de Google OAuth correctamente configuradas.

Validación rápida del entorno:

```bash
flutter doctor
```

## Configuración de entorno

La aplicación usa variables de compilación con dart-define.

Variables soportadas:

- API_BASE_URL
- GOOGLE_SERVER_CLIENT_ID
- APPLICATIONINSIGHTS_CONNECTION_STRING

Archivos de ejemplo incluidos:

- env/local.android.example.json
- env/local.ios.example.json
- env/local.device.example.json

### 1) Crear archivo local

En Windows PowerShell:

```powershell
Copy-Item env/local.android.example.json env/local.android.json
```

En Bash:

```bash
cp env/local.android.example.json env/local.android.json
```

### 2) Ajustar valores

Reemplazar en el archivo local:

- API_BASE_URL con la URL del backend para tu plataforma.
- GOOGLE_SERVER_CLIENT_ID con tu Web Client ID.
- APPLICATIONINSIGHTS_CONNECTION_STRING si aplica telemetría.

### 3) Ejecutar con variables

```bash
flutter run --dart-define-from-file=env/local.android.json
```

URLs recomendadas por plataforma:

- Android Emulator: http://10.0.2.2:3000/api
- iOS Simulator: http://localhost:3000/api
- Dispositivo físico: http://IP_DE_TU_PC:3000/api

Nota: para dispositivo físico, móvil y PC deben estar en la misma red.

## Ejecución local

Instalar dependencias:

```bash
flutter pub get
```

Ejecutar la aplicación:

```bash
flutter run --dart-define-from-file=env/local.android.json
```

Compilar release (ejemplo Android):

```bash
flutter build apk --release --dart-define-from-file=env/local.android.json
```

## Calidad y pruebas

Análisis estático:

```bash
flutter analyze
```

Formato:

```bash
dart format --set-exit-if-changed .
```

Pruebas:

```bash
flutter test
```

Cobertura:

```bash
flutter test --coverage
```

## Estructura del proyecto

```text
lib/
	core/           Configuración global, constantes, DI, utilidades
	data/           Modelos, fuentes de datos y repositorios
	domain/         Entidades y casos de uso
	presentation/   Pantallas, widgets y gestión de estado
	services/       Integraciones y servicios específicos
	utils/          Helpers transversales
test/             Pruebas automatizadas
env/              Archivos de configuración local por plataforma
```

## Convenciones de desarrollo

- Mantener separación por capas y dependencias dirigidas hacia domain.
- Evitar lógica de negocio en widgets de presentación.
- Centralizar configuración en constantes y servicios de core.
- Ejecutar análisis y pruebas antes de abrir cambios.
- Documentar cualquier variable de entorno nueva en este README.

## Solución de problemas comunes

1. No conecta al backend en Android Emulator.
Usar http://10.0.2.2:3000/api y verificar puerto expuesto.

2. Fallo en Google Sign-In.
Confirmar GOOGLE_SERVER_CLIENT_ID correcto y configuración OAuth en Google Cloud.

3. Error de red en dispositivo físico.
Verificar que el backend use la IP local del equipo y que ambos estén en la misma red.

4. Build inconsistente tras cambiar dependencias.
Ejecutar flutter clean seguido de flutter pub get.

## Roadmap recomendado para el README

Para llevar esta documentación a nivel de entrega empresarial, se recomienda añadir en siguientes iteraciones:

1. Sección de capturas de pantalla por flujo principal (login, búsqueda, solicitud, seguimiento).
2. Diagrama de arquitectura de alto nivel (cliente, API, servicios externos).
3. Matriz de ambientes (dev, qa, prod) con diferencias de configuración.
4. Política de versionado y changelog.
5. Guía de contribución formal con estrategia de ramas y checklist de PR.
6. Métricas de calidad mínimas (cobertura objetivo, reglas de lint obligatorias).
7. Estrategia de CI/CD con comandos de build y validaciones automáticas.

## Licencia y contexto académico

Proyecto universitario desarrollado para IETI (10mo semestre).

Si el repositorio evoluciona a uso productivo, se recomienda definir licencia explícita y política de contribución.
