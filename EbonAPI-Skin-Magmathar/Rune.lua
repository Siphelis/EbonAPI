if not (EbonAPI and EbonAPI.Emblem and EbonAPI.Emblem.register) then
  return
end

local STEP = 1 / 30
local DT_MAX = 0.05
local TWO_PI = 2 * math.pi
local BRAISES = 12
local GERBE = 24
local MONTANTES = 20
local COUREURS = 8
local VOLUTES = 7
local LISSAGE = 4
local FONDU_IN = 0.1
local FONDU_OUT = 0.25
local MARGE_U = 0.02
local FUMEE_MAX = 8
local ESCARBILLES = 3
local T_ONDE = 1.1
local T_FROID = 1.0
local T_GERBE = 0.9
local T_FUMEE = 1.0
local T_NAISSANCE = 0.1
local T_ESCARBILLE = 2.0
local PERIODES = { 1.9, 2.3, 2.4 }
local ART = "Interface\\AddOns\\EbonAPI-Skin-Magmathar\\Media\\Rune\\"

local floor, max, min, abs, sin, cos, sqrt = math.floor, math.max, math.min, math.abs, math.sin, math.cos, math.sqrt
local atan2, pi = math.atan2, math.pi

local C_ONDE = { 1, 0.55, 0.2 }
local C_FROID = { 0.5, 0.24, 0.12 }

local TIMERS = { "ot", "ft", "gt", "st" }

local TRACES = {
  { closed = false, p = {
    -0.36, -0.048, -0.3468, -0.0481, -0.3336, -0.0481, -0.3204, -0.0481, -0.3073, -0.0482, -0.2941, -0.0483,
    -0.2809, -0.0483, -0.2677, -0.0484, -0.2545, -0.0484, -0.2413, -0.0485, -0.2281, -0.0485, -0.215, -0.0486,
    -0.2018, -0.0486, -0.1886, -0.0487, -0.1754, -0.0487, -0.1622, -0.0488, -0.149, -0.0488, -0.1358, -0.0489,
    -0.1226, -0.0489, -0.1095, -0.049, -0.0963, -0.049, -0.0831, -0.0491, -0.0699, -0.0491, -0.0567, -0.0492,
    -0.0435, -0.0492, -0.0303, -0.0493, -0.0171, -0.0493, -0.004, -0.0494, 0.0092, -0.0494, 0.0224, -0.0495,
    0.0356, -0.0495, 0.0488, -0.0496, 0.062, -0.0496, 0.0751, -0.0497, 0.0883, -0.0497, 0.1015, -0.0498,
    0.1147, -0.0498, 0.1279, -0.0499, 0.1411, -0.0499, 0.1543, -0.05, 0.1675, -0.05, 0.1806, -0.0501,
    0.1938, -0.0501, 0.207, -0.0502, 0.2202, -0.0502, 0.2334, -0.0503, 0.2466, -0.0503, 0.2598, -0.0504,
    0.273, -0.0504, 0.2861, -0.0505, 0.2993, -0.0505, 0.3125, -0.0506, 0.3257, -0.0506, 0.3389, -0.0507,
    0.3521, -0.0508, 0.3653, -0.0508, 0.3784, -0.0508, 0.3916, -0.0509, 0.4048, -0.051,
  } },
  { closed = false, p = {
    0.1689, -0.3082, 0.1387, -0.3154, 0.1079, -0.3191, 0.0769, -0.3194, 0.046, -0.3163, 0.0157, -0.3095,
    -0.0135, -0.2991, -0.0414, -0.2855, -0.0677, -0.2689, -0.0919, -0.2495, -0.1134, -0.2272, -0.1324, -0.2026,
    -0.1484, -0.1761, -0.1615, -0.1479, -0.1711, -0.1184, -0.1771, -0.0879, -0.1796, -0.057, -0.1787, -0.026,
    -0.1744, 0.0047, -0.1662, 0.0347, -0.1547, 0.0635, -0.14, 0.0909, -0.1224, 0.1164, -0.1019, 0.1398,
    -0.0788, 0.1604, -0.0535, 0.1784, -0.0263, 0.1934, 0.0023, 0.2053, 0.0323, 0.2136, 0.0629, 0.2183,
    0.0939, 0.2197, 0.1249, 0.2176, 0.1554, 0.2119, 0.1776, 0.2099,
  } },
  { closed = false, p = {
    0.1776, 0.2099, 0.1466, 0.2077, 0.1161, 0.2019, 0.0865, 0.1925, 0.0583, 0.1796, 0.0318, 0.1635,
    0.0074, 0.1442, -0.0146, 0.1223, -0.0336, 0.0978, -0.0499, 0.0714, -0.0626, 0.043, -0.0721, 0.0135,
    -0.0777, -0.017, -0.0799, -0.048, -0.0782, -0.079, -0.073, -0.1095, -0.064, -0.1393, -0.0516, -0.1677,
    -0.036, -0.1945, -0.0172, -0.2192, 0.0043, -0.2416, 0.0285, -0.2611, 0.0547, -0.2778, 0.0828, -0.2909,
    0.1122, -0.3009, 0.1426, -0.3071, 0.1689, -0.3082,
  } },
  { closed = false, p = {
    0.225, -0.145, 0.2315, -0.1419, 0.2379, -0.1387, 0.2444, -0.1356, 0.2508, -0.1324, 0.2573, -0.1293,
    0.2638, -0.1261, 0.2702, -0.123, 0.2767, -0.1198, 0.2832, -0.1167, 0.2896, -0.1135, 0.2961, -0.1104,
    0.3025, -0.1072, 0.309, -0.1041, 0.3155, -0.1009, 0.3219, -0.0978, 0.3284, -0.0946, 0.3348, -0.0915,
    0.3413, -0.0884, 0.3478, -0.0852, 0.3542, -0.0821, 0.3607, -0.0789, 0.3671, -0.0758, 0.3736, -0.0726,
    0.38, -0.0695, 0.3865, -0.0663, 0.393, -0.0632, 0.3994, -0.06, 0.4059, -0.0569, 0.4124, -0.0537,
  } },
  { closed = false, p = {
    0.4105, -0.0479, 0.4039, -0.0451, 0.3973, -0.0423, 0.3907, -0.0395, 0.384, -0.0367, 0.3774, -0.034,
    0.3708, -0.0312, 0.3641, -0.0284, 0.3575, -0.0256, 0.3509, -0.0228, 0.3443, -0.0201, 0.3377, -0.0173,
    0.331, -0.0145, 0.3244, -0.0117, 0.3178, -0.0089, 0.3111, -0.0062, 0.3045, -0.0034, 0.2979, -0.0006,
    0.2913, 0.0022, 0.2846, 0.005, 0.278, 0.0077, 0.2714, 0.0105, 0.2648, 0.0133, 0.2581, 0.0161,
    0.2515, 0.0189, 0.2449, 0.0217, 0.2382, 0.0244, 0.2316, 0.0272, 0.225, 0.03,
  } },
  { closed = false, p = {
    -0.385, -0.115, -0.3836, -0.114, -0.3823, -0.113, -0.3809, -0.112, -0.3796, -0.111, -0.3782, -0.11,
    -0.3769, -0.109, -0.3755, -0.108, -0.3741, -0.107, -0.3728, -0.106, -0.3714, -0.105, -0.3701, -0.104,
    -0.3687, -0.103, -0.3674, -0.102, -0.366, -0.101, -0.3647, -0.1, -0.3633, -0.099, -0.3619, -0.098,
    -0.3606, -0.097, -0.3592, -0.096, -0.3579, -0.095, -0.3565, -0.094, -0.3552, -0.093, -0.3538, -0.092,
    -0.3525, -0.091, -0.3511, -0.09, -0.3498, -0.089, -0.3484, -0.088, -0.347, -0.087, -0.3457, -0.086,
    -0.3443, -0.085, -0.343, -0.084, -0.3416, -0.083, -0.3402, -0.082, -0.3389, -0.081, -0.3375, -0.08,
    -0.3362, -0.079, -0.3348, -0.078, -0.3335, -0.077, -0.3321, -0.076, -0.3308, -0.075, -0.3294, -0.074,
    -0.3281, -0.073, -0.3267, -0.072, -0.3253, -0.071, -0.324, -0.07, -0.3226, -0.069, -0.3213, -0.068,
    -0.3199, -0.067, -0.3186, -0.066, -0.3172, -0.065, -0.3159, -0.064, -0.3145, -0.063, -0.3131, -0.062,
    -0.3118, -0.061, -0.3104, -0.06, -0.3091, -0.059, -0.3077, -0.058, -0.3064, -0.057, -0.305, -0.056,
  } },
  { closed = false, p = {
    -0.335, -0.115, -0.3336, -0.114, -0.3323, -0.113, -0.3309, -0.112, -0.3296, -0.111, -0.3282, -0.11,
    -0.3269, -0.109, -0.3255, -0.108, -0.3241, -0.107, -0.3228, -0.106, -0.3214, -0.105, -0.3201, -0.104,
    -0.3187, -0.103, -0.3174, -0.102, -0.316, -0.101, -0.3147, -0.1, -0.3133, -0.099, -0.312, -0.098,
    -0.3106, -0.097, -0.3092, -0.096, -0.3079, -0.095, -0.3065, -0.094, -0.3052, -0.093, -0.3038, -0.092,
    -0.3025, -0.091, -0.3011, -0.09, -0.2998, -0.089, -0.2984, -0.088, -0.297, -0.087, -0.2957, -0.086,
    -0.2943, -0.085, -0.293, -0.084, -0.2916, -0.083, -0.2903, -0.082, -0.2889, -0.081, -0.2875, -0.08,
    -0.2862, -0.079, -0.2848, -0.078, -0.2835, -0.077, -0.2821, -0.076, -0.2808, -0.075, -0.2794, -0.074,
    -0.2781, -0.073, -0.2767, -0.072, -0.2753, -0.071, -0.274, -0.07, -0.2726, -0.069, -0.2713, -0.068,
    -0.2699, -0.067, -0.2686, -0.066, -0.2672, -0.065, -0.2658, -0.064, -0.2645, -0.063, -0.2631, -0.062,
    -0.2618, -0.061, -0.2604, -0.06, -0.2591, -0.059, -0.2577, -0.058, -0.2564, -0.057, -0.255, -0.056,
  } },
  { closed = false, p = {
    -0.39, 0.025, -0.3886, 0.0239, -0.3873, 0.0229, -0.3859, 0.0218, -0.3846, 0.0207, -0.3832, 0.0197,
    -0.3819, 0.0186, -0.3805, 0.0175, -0.3791, 0.0165, -0.3778, 0.0154, -0.3764, 0.0143, -0.3751, 0.0132,
    -0.3737, 0.0122, -0.3724, 0.0111, -0.371, 0.01, -0.3697, 0.009, -0.3683, 0.0079, -0.3669, 0.0069,
    -0.3656, 0.0058, -0.3642, 0.0047, -0.3629, 0.0036, -0.3615, 0.0026, -0.3602, 0.0015, -0.3588, 0.0004,
    -0.3575, -0.0006, -0.3561, -0.0017, -0.3548, -0.0028, -0.3534, -0.0038, -0.352, -0.0049, -0.3507, -0.006,
    -0.3493, -0.007, -0.348, -0.0081, -0.3466, -0.0092, -0.3453, -0.0102, -0.3439, -0.0113, -0.3425, -0.0124,
    -0.3412, -0.0134, -0.3398, -0.0145, -0.3385, -0.0156, -0.3371, -0.0166, -0.3358, -0.0177, -0.3344, -0.0188,
    -0.3331, -0.0198, -0.3317, -0.0209, -0.3303, -0.022, -0.329, -0.0231, -0.3276, -0.0241, -0.3263, -0.0252,
    -0.3249, -0.0262, -0.3236, -0.0273, -0.3222, -0.0284, -0.3209, -0.0295, -0.3195, -0.0305, -0.3181, -0.0316,
    -0.3168, -0.0327, -0.3154, -0.0337, -0.3141, -0.0348, -0.3127, -0.0359, -0.3114, -0.0369, -0.31, -0.038,
  } },
  { closed = false, p = {
    -0.345, 0.025, -0.3436, 0.0239, -0.3423, 0.0229, -0.3409, 0.0218, -0.3396, 0.0207, -0.3382, 0.0197,
    -0.3369, 0.0186, -0.3355, 0.0175, -0.3342, 0.0165, -0.3328, 0.0154, -0.3314, 0.0143, -0.3301, 0.0132,
    -0.3287, 0.0122, -0.3274, 0.0111, -0.326, 0.01, -0.3247, 0.009, -0.3233, 0.0079, -0.322, 0.0069,
    -0.3206, 0.0058, -0.3192, 0.0047, -0.3179, 0.0036, -0.3165, 0.0026, -0.3152, 0.0015, -0.3138, 0.0004,
    -0.3125, -0.0006, -0.3111, -0.0017, -0.3098, -0.0028, -0.3084, -0.0038, -0.307, -0.0049, -0.3057, -0.006,
    -0.3043, -0.007, -0.303, -0.0081, -0.3016, -0.0092, -0.3003, -0.0102, -0.2989, -0.0113, -0.2975, -0.0124,
    -0.2962, -0.0134, -0.2948, -0.0145, -0.2935, -0.0156, -0.2921, -0.0166, -0.2908, -0.0177, -0.2894, -0.0188,
    -0.288, -0.0198, -0.2867, -0.0209, -0.2853, -0.022, -0.284, -0.0231, -0.2826, -0.0241, -0.2813, -0.0252,
    -0.2799, -0.0262, -0.2786, -0.0273, -0.2772, -0.0284, -0.2758, -0.0295, -0.2745, -0.0305, -0.2731, -0.0316,
    -0.2718, -0.0327, -0.2704, -0.0337, -0.2691, -0.0348, -0.2677, -0.0359, -0.2664, -0.0369, -0.265, -0.038,
  } },
  { closed = false, p = {
    0.3591, -0.2691, 0.3575, -0.2675, 0.3558, -0.2658, 0.3542, -0.2642, 0.3526, -0.2626, 0.3509, -0.261,
    0.3493, -0.2594, 0.3474, -0.258, 0.3457, -0.2565, 0.3438, -0.2551, 0.3421, -0.2536, 0.3402, -0.2522,
    0.3384, -0.2508, 0.3367, -0.2493, 0.3348, -0.2479, 0.3331, -0.2464, 0.3312, -0.245, 0.3295, -0.2436,
    0.3276, -0.2421, 0.3258, -0.2407, 0.3239, -0.2395, 0.3218, -0.2386, 0.3196, -0.2377, 0.3175, -0.2368,
    0.3154, -0.2359, 0.3133, -0.235, 0.3112, -0.2341, 0.3091, -0.2332, 0.3069, -0.2323, 0.3048, -0.2314,
    0.3027, -0.2304, 0.3006, -0.2295, 0.2985, -0.2286, 0.2964, -0.2277, 0.2942, -0.2268, 0.2921, -0.2259,
    0.29, -0.225,
  } },
  { closed = false, p = {
    -0.26, -0.305, -0.261, -0.304, -0.262, -0.303, -0.263, -0.302, -0.264, -0.301, -0.2649, -0.3001,
    -0.2659, -0.2991, -0.2669, -0.2981, -0.2679, -0.2971, -0.2689, -0.2961, -0.2699, -0.2951, -0.2709, -0.2941,
    -0.2719, -0.2931, -0.2728, -0.2922, -0.2738, -0.2912, -0.2748, -0.2902, -0.2758, -0.2892, -0.2768, -0.2882,
    -0.2778, -0.2872, -0.2788, -0.2862, -0.2798, -0.2852, -0.2809, -0.2845, -0.2821, -0.2837, -0.2833, -0.283,
    -0.2845, -0.2823, -0.2857, -0.2816, -0.2869, -0.2809, -0.2881, -0.2801, -0.2893, -0.2794, -0.2905, -0.2787,
    -0.2917, -0.278, -0.2929, -0.2773, -0.2941, -0.2766, -0.2953, -0.2758, -0.2965, -0.2751, -0.2977, -0.2744,
    -0.2989, -0.2737, -0.3001, -0.273, -0.3013, -0.2722, -0.3025, -0.2715, -0.3037, -0.2708, -0.3049, -0.2701,
    -0.306, -0.2692, -0.3071, -0.2684, -0.3082, -0.2676, -0.3094, -0.2667, -0.3105, -0.2659, -0.3116, -0.2651,
    -0.3127, -0.2642, -0.3138, -0.2634, -0.3149, -0.2626, -0.3161, -0.2617, -0.3172, -0.2609, -0.3183, -0.26,
    -0.3194, -0.2592, -0.3205, -0.2584, -0.3216, -0.2575, -0.3228, -0.2567, -0.3239, -0.2558, -0.325, -0.255,
  } },
  { closed = false, p = {
    -0.23, 0.195, -0.2317, 0.1983, -0.2333, 0.2017, -0.235, 0.205, -0.2367, 0.2084, -0.2383, 0.2117,
    -0.24, 0.215, -0.2417, 0.2184, -0.2434, 0.2217, -0.245, 0.225, -0.2467, 0.2284, -0.2484, 0.2317,
    -0.25, 0.2351, -0.2517, 0.2384, -0.2534, 0.2417, -0.255, 0.2451, -0.2567, 0.2484, -0.2584, 0.2517,
    -0.2601, 0.2551, -0.2627, 0.2577, -0.2653, 0.2603, -0.268, 0.263, -0.2706, 0.2656, -0.2732, 0.2682,
    -0.2759, 0.2709, -0.2785, 0.2735, -0.2812, 0.2762, -0.2838, 0.2788, -0.2864, 0.2814, -0.2891, 0.2841,
    -0.2917, 0.2867, -0.2944, 0.2894, -0.297, 0.292, -0.2996, 0.2946, -0.3023, 0.2973, -0.3049, 0.2999,
    -0.307, 0.303, -0.3091, 0.3061, -0.3111, 0.3092, -0.3132, 0.3123, -0.3153, 0.3154,
  } },
  { closed = false, p = {
    0.4198, 0.1826, 0.4145, 0.1852, 0.4093, 0.1879, 0.4041, 0.1905, 0.3988, 0.1931, 0.3936, 0.1957,
    0.3883, 0.1983, 0.3831, 0.2009, 0.3779, 0.2036, 0.3726, 0.2062, 0.3674, 0.2088, 0.3628, 0.2122,
    0.3586, 0.2164, 0.3545, 0.2205, 0.3503, 0.2247, 0.347, 0.2295, 0.3438, 0.2344, 0.3405, 0.2392,
    0.3373, 0.2441, 0.334, 0.249, 0.3308, 0.2539, 0.3275, 0.2587, 0.3243, 0.2636, 0.321, 0.2685,
    0.3178, 0.2733, 0.3145, 0.2782, 0.3113, 0.2831, 0.307, 0.2868, 0.3019, 0.2898, 0.2969, 0.2929,
    0.2919, 0.2959, 0.2869, 0.2989, 0.2817, 0.3016, 0.2765, 0.3043, 0.2712, 0.3069, 0.266, 0.3095,
    0.2608, 0.3121, 0.2555, 0.3147, 0.2503, 0.3174, 0.245, 0.32, 0.2398, 0.3226, 0.2346, 0.3252,
    0.2293, 0.3278, 0.2245, 0.3309, 0.2216, 0.336, 0.2187, 0.3411, 0.2158, 0.3461, 0.2129, 0.3512,
    0.21, 0.3563, 0.2071, 0.3614, 0.2042, 0.3665, 0.2016, 0.3718, 0.199, 0.377, 0.1964, 0.3822,
  } },
}

local RAYON = {
  0.424, 0.419, 0.417, 0.42, 0.432, 0.44, 0.449, 0.455,
  0.461, 0.461, 0.459, 0.458, 0.458, 0.453, 0.445, 0.439,
  0.436, 0.435, 0.442, 0.449, 0.452, 0.446, 0.459, 0.467,
  0.461, 0.451, 0.44, 0.432, 0.427, 0.42, 0.417, 0.416,
  0.417, 0.423, 0.433, 0.449, 0.465, 0.475, 0.474, 0.455,
  0.449, 0.455, 0.459, 0.453, 0.449, 0.445, 0.438, 0.43,
  0.424, 0.423, 0.422, 0.429, 0.432, 0.432, 0.426, 0.44,
  0.449, 0.455, 0.459, 0.458, 0.458, 0.453, 0.445, 0.435,
}

local function prepare()
  for _, T in ipairs(TRACES) do
    local q = {}
    for i = 1, #T.p do
      q[i] = T.p[i]
    end
    if T.closed then
      q[#q + 1] = q[1]
      q[#q + 1] = q[2]
    end
    local cum = { 0 }
    for i = 2, #q / 2 do
      local dx, dy = q[2 * i - 1] - q[2 * i - 3], q[2 * i] - q[2 * i - 2]
      cum[i] = cum[i - 1] + sqrt(dx * dx + dy * dy)
    end
    T.q = q
    T.cum = cum
    T.total = cum[#cum]
    local m = #q / 2
    local tx, ty = {}, {}
    for i = 1, m do
      local a, b = i - LISSAGE, i + LISSAGE
      if T.closed then
        a = (a - 1) % (m - 1) + 1
        b = (b - 1) % (m - 1) + 1
      else
        a, b = max(a, 1), min(b, m)
      end
      local dx, dy = q[2 * b - 1] - q[2 * a - 1], q[2 * b] - q[2 * a]
      local l = sqrt(dx * dx + dy * dy)
      if l > 0 then
        dx, dy = dx / l, dy / l
      end
      tx[i], ty[i] = dx, dy
    end
    T.tx, T.ty = tx, ty
  end
end

prepare()

local function rnd(v, k)
  return floor(v * k + 0.5) / k
end

local function lerp(a, b, u)
  return a + (b - a) * u
end

local function ease(p)
  return p * p * (3 - 2 * p)
end

local function hash(n, k)
  local v = sin(n * 12.9898 + k * 78.233) * 43758.5453
  return v - floor(v)
end

local function newAnim(v)
  return { v = v, from = v, to = v, t = 1, dl = 0, dur = 0.001 }
end

local function animGo(a, to, dur, delay)
  a.from = a.v
  a.to = to
  a.t = 0
  a.dl = delay or 0
  a.dur = max(0.001, dur * max(abs(to - a.v), 0.2))
end

local function animStep(a, dt)
  local total = a.dl + a.dur
  if a.t >= total then
    return
  end
  a.t = min(total, a.t + dt)
  local p = (a.t - a.dl) / a.dur
  if p <= 0 then
    a.v = a.from
  elseif p >= 1 then
    a.v = a.to
  else
    a.v = a.from + (a.to - a.from) * ease(p)
  end
end

local function mk(frame, name, blend, size)
  local t = frame:CreateTexture(nil, "ARTWORK")
  t:SetTexture(ART .. name .. ".tga")
  t:SetBlendMode(blend)
  t:SetSize(size, size)
  t:SetPoint("CENTER", frame, "CENTER", 0, 0)
  t:SetAlpha(0)
  t:Hide()
  return { t = t, f = frame, w = size, s = false, x = 0, y = 0, a = 0 }
end

local function opa(L, v)
  if v < 0 then
    v = 0
  elseif v > 1 then
    v = 1
  end
  v = floor(v * 100 + 0.5) / 100
  if v ~= L.a then
    L.a = v
    L.t:SetAlpha(v)
  end
  local vis = v > 0
  if vis ~= L.s then
    L.s = vis
    if vis then
      L.t:Show()
    else
      L.t:Hide()
    end
  end
end

local function sz(L, w)
  w = rnd(w, 10)
  if w ~= L.w then
    L.w = w
    L.t:SetSize(w, w)
  end
end

local function tint(L, r, g, b)
  r, g, b = rnd(r, 1000), rnd(g, 1000), rnd(b, 1000)
  if r ~= L.r or g ~= L.g or b ~= L.b then
    L.r, L.g, L.b = r, g, b
    L.t:SetVertexColor(r, g, b)
  end
end

local function put(L, x, y, k)
  k = k or 10
  x, y = rnd(x, k), rnd(y, k)
  if x ~= L.x or y ~= L.y then
    L.x, L.y = x, y
    L.t:SetPoint("CENTER", L.f, "CENTER", x, y)
  end
end

local function uv(X, Y, ux, uy, len, w)
  local s = X * ux + Y * uy
  local n = Y * ux - X * uy
  return 0.5 + s / len, 0.5 - n / w
end

local function turn(L, deg, len, w)
  deg = floor((deg % 360) / 2 + 0.5) * 2
  if deg ~= L.dg then
    L.dg = deg
    local r = deg * pi / 180
    local ux, uy = cos(r), sin(r)
    local bw = len * abs(ux) + w * abs(uy)
    local bh = len * abs(uy) + w * abs(ux)
    local hx, hy = bw / 2, bh / 2
    local a1, a2 = uv(-hx, hy, ux, uy, len, w)
    local b1, b2 = uv(-hx, -hy, ux, uy, len, w)
    local c1, c2 = uv(hx, hy, ux, uy, len, w)
    local d1, d2 = uv(hx, -hy, ux, uy, len, w)
    L.t:SetTexCoord(a1, a2, b1, b2, c1, c2, d1, d2)
    L.t:SetSize(bw, bh)
  end
end

local function layer(body, side, i)
  local f = CreateFrame("Frame", nil, body)
  f:SetSize(side, side)
  f:SetPoint("CENTER", body, "CENTER", 0, 0)
  f:SetFrameLevel(body:GetFrameLevel() + i)
  f:EnableMouse(false)
  return f
end

local function onTrace(T, s, R)
  local c, q = T.cum, T.q
  local n = #c
  local i = R.i
  if s < c[i] then
    i = 1
  end
  while i < n - 1 and c[i + 1] < s do
    i = i + 1
  end
  R.i = i
  local d = c[i + 1] - c[i]
  local u = d > 0 and (s - c[i]) / d or 0
  local x1, y1, x2, y2 = q[2 * i - 1], q[2 * i], q[2 * i + 1], q[2 * i + 2]
  local ax, ay = lerp(T.tx[i], T.tx[i + 1], u), lerp(T.ty[i], T.ty[i + 1], u)
  return lerp(x1, x2, u), lerp(y1, y2, u), ax, ay
end

local function dedans(x, y, side)
  local r2 = x * x + y * y
  if r2 < 1e-6 then
    return true
  end
  local f = (atan2(y, x) / TWO_PI) % 1 * #RAYON
  local i = floor(f)
  local a, b = RAYON[i + 1], RAYON[i % #RAYON + 2] or RAYON[1]
  local l = min(a, b) * side
  return r2 <= l * l
end

local function tient(S, x0, y0, dx, dy, t)
  local side = S.side
  for j = 1, 4 do
    if not dedans(x0 + dx * t * j / 4, y0 + dy * t * j / 4, side) then
      return false
    end
  end
  return true
end

local function portee(S, x0, y0, dx, dy)
  if tient(S, x0, y0, dx, dy, 1) then
    return 1
  end
  local lo, hi = 0, 1
  for _ = 1, 7 do
    local mid = (lo + hi) / 2
    if tient(S, x0, y0, dx, dy, mid) then
      lo = mid
    else
      hi = mid
    end
  end
  return lo
end

local function paintRunners(S, aa)
  local side = S.side
  for k = 1, COUREURS do
    local R = S.run[k]
    if aa > 0 then
      local T = TRACES[k]
      local u = (R.ph + S.c / R.per) % 1
      local f = 0
      if u > MARGE_U and u < 1 - MARGE_U then
        f = min(ease(min(1, (u - MARGE_U) / (FONDU_IN - MARGE_U))), ease(min(1, (1 - MARGE_U - u) / FONDU_OUT)))
      end
      if f > 0 then
        local x, y, dx, dy = onTrace(T, u * T.total, R)
        if dx ~= 0 or dy ~= 0 then
          R.deg = atan2(-dy, dx) * 180 / pi
        end
        turn(R, R.deg, S.rlen, S.rwid)
        put(R, x * side, -y * side, 100)
      end
      opa(R, aa * f)
    else
      opa(R, 0)
    end
  end
end

local function life(L)
  if not L.ag then
    return
  end
  local p = L.ag / L.du
  if p >= 1 then
    L.ag = nil
    opa(L, 0)
    return
  end
  return p
end

local function age(pool, dt)
  for _, L in ipairs(pool) do
    if L.ag then
      L.ag = L.ag + dt
    end
  end
end

local function pool(frame, name, blend, size, n, init)
  local list = {}
  for i = 1, n do
    local L = mk(frame, name, blend, size)
    if init then
      init(L, i)
    end
    list[i] = L
  end
  return list
end

local function progress(S, key, dur)
  local t = S[key]
  if not t then
    return
  end
  local p = t / dur
  if p >= 1 then
    S[key] = nil
  end
  return p
end

local function paintSparks(S)
  for _, Q in ipairs(S.mont) do
    local p = life(Q)
    if p then
      put(Q, Q.x0 + Q.dx * p, Q.y0 + Q.ry * p)
      opa(Q, 1 - p)
    end
  end
end

local function paintEmbers(S)
  for _, E in ipairs(S.escs) do
    local p = life(E)
    if p then
      put(E, E.x0, E.y0 + E.v * E.ag)
      opa(E, 0.85 * sin(pi * p))
    end
  end
end

local function paintSmoke(S)
  local side = S.side
  local done = true
  for j = 1, VOLUTES do
    local V = S.fum[j]
    local ecart = S.st - V.dl
    if ecart >= T_FUMEE then
      opa(V, 0)
    elseif ecart < 0 then
      done = false
    else
      done = false
      local p = ecart / T_FUMEE
      sz(V, side * 0.3 * (0.8 + 0.4 * p))
      put(V, V.x0, V.y0 + V.ry * p)
      opa(V, 0.5 * sin(pi * p))
    end
  end
  if done then
    S.st = nil
  end
end

local function paint(S)
  local side = S.side
  local lm = S.aLm.v
  local base = lerp(0.37, 0.75, lm) + lerp(0.21, 0.15, lm) * sin(S.pL)
  opa(S.lueur, base + (0.9 - base) * S.aEcl.v)

  local av = S.aV.v
  opa(S.veille, av)
  if av > 0 then
    local ph = TWO_PI * S.c / 5.6
    local k = 0.5 - 0.5 * cos(ph)
    sz(S.veille, side * (1 + 0.014 * k))
    sz(S.gravure, side * (1 + 0.014 * k))
    local g = 1 - 0.1 * k
    tint(S.veille, g, g, g)
  end

  local aa = S.aA.v
  opa(S.actif, aa)
  if aa > 0 then
    local g = 0.985 + 0.015 * sin(TWO_PI * S.c / 2.8)
    tint(S.actif, g, g, g)
  end
  opa(S.feu, aa * (0.89 + 0.11 * sin(TWO_PI * S.c / 1.37)))
  paintRunners(S, aa)

  local u = 0.5 + 0.5 * sin(TWO_PI * S.c / 2.8 + 1)
  opa(S.gravure, 0.35 * u * av * (1 - aa))

  for i = 1, BRAISES do
    opa(S.braises[i], 0.485 + 0.265 * sin(S.pB[i]))
  end

  local po = progress(S, "ot", T_ONDE)
  if po then
    if po >= 1 then
      opa(S.onde, 0)
    else
      sz(S.onde, side * (0.6 + 0.65 * (1 - (1 - po) * (1 - po))))
      opa(S.onde, 1 - po)
    end
  end

  local pf = progress(S, "ft", T_FROID)
  if pf then
    opa(S.froid, pf >= 1 and 0 or 1 - pf)
  end

  local pg = progress(S, "gt", T_GERBE)
  if pg then
    local e = 1 - (1 - pg) * (1 - pg)
    for _, G in ipairs(S.gerbe) do
      if pg >= 1 then
        opa(G, 0)
      else
        put(G, G.dx * e, G.dy * e)
        opa(G, 1 - pg)
      end
    end
  end

  paintSparks(S)
  paintEmbers(S)
  if S.st then
    paintSmoke(S)
  end
end

local function spawnSpark(S)
  S.bn = S.bn + 1
  local n = S.bn
  local Q = S.mont[(n - 1) % MONTANTES + 1]
  local side = S.side
  Q.du = 0.5 + 0.4 * hash(n, 3)
  Q.ry = side * (0.22 + 0.16 * hash(n, 4))
  Q.dx = side * (hash(n, 5) - 0.5) * 0.16
  local j0 = floor(hash(n, 1) * #TRACES)
  local bx, by, bt = 0, 0, -1
  for a = 0, #TRACES - 1 do
    local T = TRACES[(j0 + a) % #TRACES + 1]
    local m = #T.p / 2
    local k0 = floor(hash(n, 2) * m)
    for b = 0, m - 1, 4 do
      local k = (k0 + b) % m + 1
      local x, y = T.p[2 * k - 1] * side, -T.p[2 * k] * side
      local t = portee(S, x, y, Q.dx, Q.ry)
      if t > bt then
        bx, by, bt = x, y, t
      end
      if t >= 1 then
        break
      end
    end
    if bt >= 1 then
      break
    end
  end
  Q.x0, Q.y0 = bx, by
  Q.dx, Q.ry = Q.dx * bt, Q.ry * bt
  Q.ag = 0
  put(Q, Q.x0, Q.y0)
  opa(Q, 1)
end

local function spawnEmber(S)
  S.en = S.en + 1
  local n = S.en
  local E = S.escs[(n - 1) % ESCARBILLES + 1]
  local side = S.side
  E.x0 = side * (hash(n, 11) - 0.5) * 0.3
  E.y0 = side * (hash(n, 12) * 0.05 - 0.27)
  E.du = 2.6 + 1.6 * hash(n, 13)
  E.v = side * (12 + 18 * hash(n, 14)) / 172
  E.du = E.du * portee(S, E.x0, E.y0, 0, E.v * E.du)
  E.ag = 0
end

local function tick(S, dt)
  S.c = S.c + dt
  animStep(S.aA, dt)
  animStep(S.aV, dt)
  animStep(S.aM, dt)
  animStep(S.aLm, dt)
  animStep(S.aEcl, dt)
  S.pL = S.pL + dt * TWO_PI * lerp(1 / 2.8, 1 / 2.3, S.aLm.v)
  local w = dt * TWO_PI * lerp(1 / 2.8, 1 / 1.37, S.aM.v)
  for i = 1, BRAISES do
    S.pB[i] = S.pB[i] + w
  end
  for _, k in ipairs(TIMERS) do
    if S[k] then
      S[k] = S[k] + dt
    end
  end
  age(S.mont, dt)
  age(S.escs, dt)
  if S.on then
    S.sb = S.sb + dt
    while S.sb >= T_NAISSANCE - 1e-9 do
      S.sb = S.sb - T_NAISSANCE
      spawnSpark(S)
    end
  else
    S.eb = S.eb + dt
    if S.eb >= T_ESCARBILLE - 1e-9 then
      S.eb = S.eb - T_ESCARBILLE
      spawnEmber(S)
    end
  end
  paint(S)
end

local function setState(S, on)
  if on == S.on then
    return
  end
  S.on = on
  if on then
    animGo(S.aA, 1, 1.1, 0.05)
    animGo(S.aV, 0, 0.4, 1.1)
    animGo(S.aM, 1, 1.0)
    animGo(S.aLm, 1, 0.8, 0.35)
    S.aEcl.v = 1
    animGo(S.aEcl, 0, 0.35, 0.1)
    S.ot = 0
    S.gt = 0
    S.sb = 0
  else
    animGo(S.aA, 0, 1.0)
    animGo(S.aV, 1, 0.2)
    animGo(S.aM, 0, 1.0)
    animGo(S.aLm, 0, 1.0)
    S.ft = 0
    S.st = 0
  end
  paint(S)
end

local function build(button, side, on)
  on = on and true or false
  local v = on and 1 or 0
  local S = {
    side = side, on = on, c = 0, acc = 0, pL = 0.6, pB = {},
    bn = 0, en = 0, sb = 0, eb = 1.0,
    rlen = floor(side * 0.2 + 0.5), rwid = floor(side * 0.2 + 0.5) / 4,
    aA = newAnim(v), aV = newAnim(1 - v), aM = newAnim(v), aLm = newAnim(v), aEcl = newAnim(0),
  }

  local body = layer(button, side, 1)
  button.body = body

  local F = {}
  for i = 1, 11 do
    F[i] = layer(body, side, i)
  end
  local fL, fV, fA, fF, fC, fR, fB, fG, fM, fS, fE = unpack(F)

  S.lueur = mk(fL, "Lueur", "ADD", floor(side * 1.35 + 0.5))
  S.veille = mk(fV, "Veille", "BLEND", side)
  S.actif = mk(fA, "Actif", "BLEND", side)
  S.feu = mk(fF, "Feu", "ADD", side)
  S.gravure = mk(fR, "Gravure", "ADD", side)
  S.onde = mk(fR, "Anneau", "ADD", side)
  S.froid = mk(fR, "Anneau", "BLEND", side)
  tint(S.onde, unpack(C_ONDE))
  tint(S.froid, unpack(C_FROID))
  sz(S.onde, side * 0.6)

  S.run = pool(fC, "Coureur", "ADD", side, COUREURS, function(R, k)
    R.i, R.deg = 1, 0
    R.per = PERIODES[(k - 1) % 3 + 1]
    R.ph = ((k - 1) * 0.381966 + 0.07) % 1
  end)

  S.braises = pool(fB, "Etincelle", "ADD", floor(side * 0.1 + 0.5), BRAISES, function(B, i)
    local ang = i * 2.39996
    local rad = side * (0.26 + 0.14 * ((i * 0.37) % 1))
    put(B, cos(ang) * rad, sin(ang) * rad)
    S.pB[i] = ((i * 0.618034) % 1) * TWO_PI
  end)

  S.gerbe = pool(fG, "Etincelle", "ADD", floor(side * 0.085 + 0.5), GERBE, function(G, i)
    local ang = i * 2.39996 + 0.5
    local c, s = cos(ang), sin(ang)
    local rad = side * (0.35 + 0.14 * ((i * 0.618034) % 1))
    local t = portee(S, 0, 0, c * rad, s * rad)
    G.dx, G.dy = c * rad * t, s * rad * t
  end)

  S.mont = pool(fM, "Etincelle", "ADD", floor(side * 0.07 + 0.5), MONTANTES)

  S.fum = pool(fS, "Fumee", "BLEND", floor(side * 0.3 + 0.5), FUMEE_MAX, function(V, j)
    V.dl = 0.025 * (j - 1)
    V.x0 = side * (0.05 * (j - 1) - 0.15)
    V.y0 = -0.3 * side
    V.ry = side * (0.1 + 0.012 * (j - 1))
  end)

  S.escs = pool(fE, "Escarbille", "ADD", floor(side * 0.045 + 0.5), ESCARBILLES)

  paint(S)

  return {
    step = function(elapsed)
      if elapsed > DT_MAX then
        elapsed = DT_MAX
      end
      if elapsed <= 0 then
        return
      end
      S.acc = S.acc + elapsed
      local n = 0
      while S.acc >= STEP - 1e-9 and n < 2 do
        S.acc = max(0, S.acc - STEP)
        n = n + 1
        tick(S, STEP)
      end
    end,
    set = function(value)
      setState(S, value and true or false)
    end,
    show = function()
      S.acc = 0
    end,
    rest = function()
      for _, Q in ipairs(S.mont) do
        Q.ag = nil
        opa(Q, 0)
      end
      for _, E in ipairs(S.escs) do
        E.ag = nil
        opa(E, 0)
      end
    end,
  }
end

EbonAPI.Emblem.register("hunt", "Magmathar", { build = build })
