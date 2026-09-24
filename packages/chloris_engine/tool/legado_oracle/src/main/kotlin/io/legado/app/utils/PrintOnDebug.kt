package io.legado.app.utils

/**
 * Stub of `io.legado.app.utils.printOnDebug`. In the real app this forwards to
 * the debug log; for the offline judging process we make it a silent no-op so
 * JSONPath / regex backends can be compiled without the Android debug channel.
 */
fun Throwable.printOnDebug() {
    // intentionally silent in the oracle
}
