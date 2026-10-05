// Deja la línea "package" que generó flutter create (depende de tu --org).
package com.example.radio_colombia

import com.ryanheise.audioservice.AudioServiceActivity

// Necesario para que el audio siga sonando en segundo plano.
class MainActivity : AudioServiceActivity()
