# CameYa - Plataforma de Servicios Bajo Demanda

Una aplicación móvil Flutter que conecta usuarios con proveedores de servicios domésticos y técnicos de manera segura, eficiente e inteligente.

## 🚀 Inicio Rápido

```bash
# Instalar dependencias
flutter pub get

# Ejecutar la aplicación
flutter run
```

## 📱 Características Principales

- ✅ Autenticación con email/contraseña
- ✅ Login con Google OAuth
- ✅ Roles de usuario: Cliente y Profesional
- ✅ Arquitectura limpia (Clean Architecture)
- ✅ Gestión de estado con BLoC
- ✅ Diseño personalizado con Material Design 3

## 🏗️ Arquitectura

Este proyecto sigue **Clean Architecture** con separación estricta de responsabilidades:

- **Presentation**: UI y BLoC (gestión de estado)
- **Domain**: Lógica de negocio, entidades y casos de uso
- **Data**: Repositorios, modelos y fuentes de datos
- **Core**: Utilidades compartidas, temas y constantes

Para más detalles, consulta [ARCHITECTURE.md](ARCHITECTURE.md).

## 📦 Stack Tecnológico

- **Flutter SDK**: 3.10.7+
- **Estado**: flutter_bloc 8.1.6
- **HTTP**: dio 5.4.0
- **DI**: get_it 7.7.0
- **Funcional**: dartz 0.10.1
- **OAuth**: google_sign_in 6.3.0
- **Storage**: shared_preferences 2.2.2

## 🔐 Backend

La aplicación se conecta a un backend NestJS en:

```
http://localhost:3000/api
```

Configurar en: `lib/core/constants/app_constants.dart`

## 📝 Comandos Útiles

```bash
# Instalar dependencias
flutter pub get

# Ejecutar la app
flutter run

# Ejecutar tests
flutter test

# Analizar código
flutter analyze

# Verificar formato
dart format --set-exit-if-changed .

# Limpiar proyecto
flutter clean
```

## 🎨 Tema y Colores

Paleta basada en el logo de CameYa:

- **Primary**: #4A80F5 (Azul)
- **Secondary**: #FFB800 (Amarillo)
- **Background**: #F5F7FA
- **Success**: #4CAF50
- **Error**: #F44336

## 📂 Estructura del Proyecto

```
lib/
├── core/              # Configuración y utilidades
├── data/              # Modelos y datasources
├── domain/            # Entidades y casos de uso
└── presentation/      # UI y BLoC
```

## 🧪 Testing

```bash
# Ejecutar todos los tests
flutter test

# Ejecutar con coverage
flutter test --coverage
```

## 📄 Licencia

Proyecto universitario - IETI (10mo Semestre)

## 👥 Contribuir

Este es un proyecto educativo. Para consultas, contactar al equipo de desarrollo.

---

**CameYa** - Servicios al Instante 🚀
