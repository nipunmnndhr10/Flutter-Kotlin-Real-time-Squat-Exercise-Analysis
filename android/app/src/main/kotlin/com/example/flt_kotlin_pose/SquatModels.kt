package com.example.flt_kotlin_pose

enum class SquatDepthPreset(
    val label: String,
    val angleThreshold: Float,
    val description: String
) {
    QUARTER_SQUAT(
        label = "Explosive Power (¼ Squat)",
        angleThreshold = 140f,
        description = "Best for vertical jump, sprinting, basketball, athletic explosiveness"
    ),
    HALF_SQUAT(
        label = "Athletic Strength (½ Squat)",
        angleThreshold = 120f,
        description = "Best for sports performance, power development, general athleticism"
    ),
    FULL_SQUAT(
        label = "Full Strength (Full Squat)",
        angleThreshold = 90f,
        description = "Best for strength training, muscle growth, full-range squat technique"
    );

    companion object {
        val DEFAULT = FULL_SQUAT

        // Safely resolve a threshold value back to its preset (used when receiving from Flutter)
        fun fromAngle(angle: Float): SquatDepthPreset =
            entries.firstOrNull { it.angleThreshold == angle } ?: DEFAULT
    }
}


// MediaPipe landmark indices 
object LM {
    const val LEFT_SHOULDER  = 11
    const val RIGHT_SHOULDER = 12
    const val LEFT_HIP       = 23
    const val RIGHT_HIP      = 24
    const val LEFT_KNEE      = 25
    const val RIGHT_KNEE     = 26
    const val LEFT_ANKLE     = 27
    const val RIGHT_ANKLE    = 28
}

enum class SquatPhase {
    STANDING, DESCENDING, BOTTOM, ASCENDING
}

enum class SquatFault(val cueName: String) {
    GO_DEEPER("go_deeper"),
    LEAN_FORWARD("chest_up"),
    LEFT_KNEE_CAVE("knees_out"),
    RIGHT_KNEE_CAVE("knees_out")
}

data class SquatFeedback(
    val phase: SquatPhase,
    val repCount: Int,
    val activeFaults: List<SquatFault>,
    val kneeAngle: Float,
    val hipAngle: Float,
    val isLandmarkReliable: Boolean,
    val activePreset: SquatDepthPreset = SquatDepthPreset.DEFAULT,
)