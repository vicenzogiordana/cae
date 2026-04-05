# Contexto Accounts

## Descripción General

El contexto `Accounts` es responsable de la gestión de identidad de usuarios y perfiles de estudiantes, siguiendo el patrón **Domain-Driven Design (DDD)** mediante Contextos de Phoenix.

### Funcionalidades Principales

- ✅ Gestión de usuarios por rol (alumno, secretaria, psicólogo, psiquiatra, psicopedagogo)
- ✅ Perfiles de estudiante (uno-a-uno con usuarios)
- ✅ Control de acceso basado en roles (RBAC)
- ✅ Soft delete de usuarios
- ✅ Gestión de permisos de administrador

---

## Estructura de Datos

### Tabla: `users`

| Campo | Tipo | Constraints |
|-------|------|------------|
| `id` | INTEGER | PRIMARY KEY, AUTO_INCREMENT |
| `university_id` | VARCHAR | UNIQUE, NOT NULL |
| `email` | VARCHAR | UNIQUE, NOT NULL |
| `first_name` | VARCHAR | |
| `last_name` | VARCHAR | |
| `role` | VARCHAR | NOT NULL (student, secretary, psychologist, psychiatrist, psychopedagogue) |
| `is_admin` | BOOLEAN | DEFAULT: false |
| `is_active` | BOOLEAN | DEFAULT: true |
| `inserted_at` | TIMESTAMP | |
| `updated_at` | TIMESTAMP | |

### Tabla: `student_profiles`

| Campo | Tipo | Constraints |
|-------|------|------------|
| `id` | INTEGER | PRIMARY KEY, AUTO_INCREMENT |
| `user_id` | INTEGER | FK → users.id, UNIQUE, NOT NULL, ON DELETE CASCADE |
| `file_number` | VARCHAR | UNIQUE |
| `address` | VARCHAR | |
| `career` | VARCHAR | |
| `current_year` | INTEGER | |
| `birth_date` | DATE | |
| `emergency_contact_name` | VARCHAR | |
| `emergency_contact_phone` | VARCHAR | |
| `emergency_contact_relationship` | VARCHAR | |
| `inserted_at` | TIMESTAMP | |
| `updated_at` | TIMESTAMP | |

---

## API del Contexto

### Registración

#### `register_student(user_attrs, profile_attrs \\ %{})`

Registra un nuevo alumno junto a su perfil usando **Ecto.Multi** para garantizar atomicidad (todo-o-nada).

**Parámetros:**
- `user_attrs`: Mapa con atributos del usuario (`university_id`, `email`, `first_name`, `last_name`)
- `profile_attrs`: Mapa con atributos del perfil (`file_number`, `address`, `career`, `current_year`, etc.)

**Retorna:**
- `{:ok, %{user: user, profile: profile}}` en caso de éxito
- `{:error, step, changeset, _}` en caso de fallo

**Ejemplo:**

```elixir
{:ok, result} = CaeNew.Accounts.register_student(
  %{
    "university_id" => "U12345",
    "email" => "juan@uni.edu",
    "first_name" => "Juan",
    "last_name" => "Pérez"
  },
  %{
    "file_number" => "EXP-001",
    "career" => "Ingeniería Informática",
    "current_year" => 2
  }
)

user = result.user
profile = result.profile
```

### Búsqueda

#### `get_user!(id)`
Obtiene un usuario por ID. Lanza `Ecto.NoResultsError` si no existe.

#### `get_user_by(attrs)`
Busca un usuario por atributos (ej: `%{university_id: "U12345"}`). Retorna `nil` si no existe.

#### `get_student_profile(user_id)`
Obtiene el perfil de un estudiante por ID de usuario.

**Ejemplo:**

```elixir
user = CaeNew.Accounts.get_user_by(%{email: "juan@uni.edu"})
profile = CaeNew.Accounts.get_student_profile(user.id)
```

### Gestión de Usuarios

#### `create_user(attrs)`
Crea un usuario genérico.

#### `create_professional(attrs)`
Crea una cuenta de profesional (psicólogo, psiquiatra, psicopedagogo).

#### `create_secretary(attrs)`
Crea una cuenta de secretaria.

#### `list_users_by_role(role)`
Lista todos los usuarios con un rol específico.

#### `list_active_users()`
Lista todos los usuarios activos.

#### `update_user(user, attrs)`
Actualiza un usuario.

#### `delete_user(user)`
Elimina un usuario permanentemente.

**Ejemplo:**

```elixir
psychologists = CaeNew.Accounts.list_users_by_role("psychologist")

{:ok, prof} = CaeNew.Accounts.create_professional(%{
  "university_id" => "PROF-001",
  "email" => "dra.garcia@uni.edu",
  "first_name" => "Dra.",
  "last_name" => "García",
  "role" => "psychologist"
})
```

### Gestión de Estado

#### `deactivate_user(user)`
Desactiva un usuario (soft delete).

#### `reactivate_user(user)`
Reactiva un usuario desactivado.

#### `promote_to_admin(user)`
Promueve un usuario a administrador.

#### `demote_from_admin(user)`
Retira permisos de administrador.

**Ejemplo:**

```elixir
user = CaeNew.Accounts.get_user!(123)
{:ok, deactivated} = CaeNew.Accounts.deactivate_user(user)
{:ok, promoted} = CaeNew.Accounts.promote_to_admin(deactivated)
```

---

## Validaciones

### Usuario
- ✓ `university_id` es obligatorio y único
- ✓ `email` es obligatorio y único
- ✓ `role` es obligatorio y debe estar en la lista permitida
- ✓ `role` se valida mediante `validate_inclusion/3`

### Perfil de Estudiante
- ✓ `user_id` es obligatorio y único (relación 1:1)
- ✓ `file_number` es único (si se especifica)
- ✓ Cascada de eliminación: eliminar usuario elimina su perfil

---

## Tests

La suite de tests incluye:
- ✓ Registración correcta de estudiantes
- ✓ Validaciones de campos obligatorios
- ✓ Restricciones de unicidad
- ✓ Búsquedas y filtros
- ✓ Gestión de estado

**Ejecutar tests:**
```bash
mix test test/cae_new/accounts_test.exs
```

---

## Notas de Arquitectura

1. **DDD**: El contexto encapsula toda la lógica relacionada con Accounts. Otros contextos (`Scheduling`, `MedicalRecords`) no deben interactuar directamente con los schemas, solo con las funciones públicas del contexto.

2. **Atomicidad**: La función `register_student/2` utiliza `Ecto.Multi` para garantizar que ambos (usuario y perfil) se crean o fallan juntos, evitando inconsistencias.

3. **Soft Delete**: Los usuarios pueden ser desactivados (`is_active: false`) en lugar de eliminados permanentemente, manteniendo la integridad referencial de datos históricos.

4. **RBAC**: El campo `role` define permisos. El campo `is_admin` proporciona acceso administrativo adicional, independiente del rol.

---

## Próximos Pasos

- Implementar autenticación y tokens (cuando sea necesario)
- Expandir validaciones de correo electrónico
- Agregar búsquedas avanzadas (filtros, paginación)
- Integración con `MedicalRecords` para auditoría
