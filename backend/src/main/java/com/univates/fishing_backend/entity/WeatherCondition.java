package com.univates.fishing_backend.entity;

public enum WeatherCondition {
    CLEAR,
    PARTLY_CLOUDY,
    CLOUDY,
    FOG,
    DRIZZLE,
    RAIN,
    SNOW,
    THUNDERSTORM;

    public static WeatherCondition fromCode(int code) {
        if (code == 0) return CLEAR;
        if (code == 1 || code == 2) return PARTLY_CLOUDY;
        if (code == 3) return CLOUDY;
        if (code == 45 || code == 48) return FOG;
        if (code == 51 || code == 53 || code == 55 || code == 56 || code == 57) return DRIZZLE;
        if (code == 61 || code == 63 || code == 65 || code == 66 || code == 67 || code == 80 || code == 81 || code == 82) return RAIN;
        if (code == 71 || code == 73 || code == 75 || code == 77 || code == 85 || code == 86) return SNOW;
        if (code == 95 || code == 96 || code == 99) return THUNDERSTORM;
        return CLOUDY;
    }
}
