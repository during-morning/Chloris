package androidx.annotation

/**
 * Minimal stub of `androidx.annotation.Keep`.
 *
 * `AnalyzeByRegex.kt` only needs this annotation to be present at compile
 * time; its runtime retention is irrelevant to the oracle. We intentionally
 * keep it a no-op so we do not pull the AndroidX annotation artifact.
 */
@Retention(AnnotationRetention.RUNTIME)
@Target(
    AnnotationTarget.CLASS,
    AnnotationTarget.ANNOTATION_CLASS,
    AnnotationTarget.FIELD,
    AnnotationTarget.FUNCTION,
    AnnotationTarget.PROPERTY_GETTER,
    AnnotationTarget.PROPERTY_SETTER,
    AnnotationTarget.CONSTRUCTOR,
)
annotation class Keep
