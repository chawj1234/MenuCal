//
//  ContentView.swift
//  menuCal
//
//  Created by 차원준 on 6/23/25.
//

import SwiftUI
import WeatherKit
import CoreLocation
import AppKit

@MainActor
class SimpleWeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var temperature: String = "?"
    @Published var condition: String = NSLocalizedString("Locating...", comment: "Location loading text")
    @Published var weatherIcon: String = "location.fill"
    @Published var iconColor: Color = .secondary
    @Published var locationName: String = NSLocalizedString("Locating...", comment: "Location loading text")
    @Published var isLoading: Bool = false
    
    private let locationManager = CLLocationManager()
    private let weatherService = WeatherService()
    private var currentLocation: CLLocation?
    private var selectedDate: Date = Date()
    
    override init() {
        super.init()
        setupLocationManager()
        requestLocation()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocation() {
        isLoading = true
        locationName = NSLocalizedString("Locating...", comment: "Location loading text")
        currentLocation = nil
        locationManager.requestLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        currentLocation = location
        loadWeather(for: location, date: selectedDate)
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        showLocationError()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            showLocationError()
        default:
            break
        }
    }
    
    // MARK: - Weather Loading
    
    func loadWeatherForDate(_ date: Date) {
        selectedDate = date
        guard let location = currentLocation else {
            showLocationError()
            return
        }
        loadWeather(for: location, date: date)
    }
    
    private func loadWeather(for location: CLLocation, date: Date) {
        isLoading = true
        
        Task {
            do {
                let weather = try await weatherService.weather(for: location)
                
                let isToday = Calendar.current.isDate(date, inSameDayAs: Date())
                let isFutureDate = date > Date()
                
                if isToday {
                    updateWeatherUI(
                        temperature: Int(weather.currentWeather.temperature.value),
                        condition: weather.currentWeather.condition,
                        date: date
                    )
                } else {
                    if let dailyForecast = weather.dailyForecast.first(where: { forecast in
                        Calendar.current.isDate(forecast.date, inSameDayAs: date)
                    }) {
                        let avgTemp = (dailyForecast.highTemperature.value + dailyForecast.lowTemperature.value) / 2
                        updateWeatherUI(
                            temperature: Int(avgTemp),
                            condition: dailyForecast.condition,
                            date: date
                        )
                    } else {
                        self.temperature = ""
                        self.condition = isFutureDate ? 
                            NSLocalizedString("Forecast data is not available yet", comment: "Forecast data not available") :
                            NSLocalizedString("We don't have data for past weather.", comment: "Past weather data not available")
                        self.weatherIcon = ""
                        self.iconColor = .secondary
                        self.isLoading = false
                    }
                }
                
                if locationName == NSLocalizedString("Locating...", comment: "Location loading text") {
                    getLocationName(for: location)
                }
                
                self.isLoading = false
            } catch {
                showWeatherError()
            }
        }
    }
    
    private func updateWeatherUI(temperature: Int, condition: WeatherCondition, date: Date) {
        self.temperature = "\(temperature)°"
        self.condition = weatherConditionText(for: condition)
        
        let iconInfo = weatherIconInfo(for: condition)
        self.weatherIcon = iconInfo.icon
        self.iconColor = iconInfo.color
    }
    
    // MARK: - Location Name
    
    private func getLocationName(for location: CLLocation) {
        let geocoder = CLGeocoder()
        
        if #available(macOS 11.0, *) {
            let systemLanguage = Locale.current.languageCode ?? "en"
            let preferredLocale = Locale(identifier: systemLanguage)
            geocoder.reverseGeocodeLocation(location, preferredLocale: preferredLocale) { [weak self] placemarks, error in
                self?.handleGeocodeResult(placemarks: placemarks, error: error)
            }
        } else {
            geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
                self?.handleGeocodeResult(placemarks: placemarks, error: error)
            }
        }
    }
    
    private func handleGeocodeResult(placemarks: [CLPlacemark]?, error: Error?) {
        DispatchQueue.main.async {
            if error != nil {
                self.locationName = NSLocalizedString("Current Location", comment: "Current location text")
                return
            }
            
            if let placemark = placemarks?.first {
                let originalLocationName = placemark.locality ?? 
                                          placemark.administrativeArea ?? 
                                          NSLocalizedString("Current Location", comment: "Current location text")
                
                let systemLanguage = Locale.current.languageCode ?? "en"
                
                if systemLanguage == "en" && self.containsKorean(originalLocationName) {
                    self.locationName = self.translateKoreanLocationToEnglish(originalLocationName)
                } else {
                    self.locationName = originalLocationName
                }
            } else {
                self.locationName = NSLocalizedString("Current Location", comment: "Current location text")
            }
        }
    }
    
    private func containsKorean(_ text: String) -> Bool {
        for character in text {
            let scalar = character.unicodeScalars.first
            if let scalar = scalar,
               (scalar.value >= 0xAC00 && scalar.value <= 0xD7AF) ||
               (scalar.value >= 0x1100 && scalar.value <= 0x11FF) ||
               (scalar.value >= 0x3130 && scalar.value <= 0x318F) ||
               (scalar.value >= 0xA960 && scalar.value <= 0xA97F) {
                return true
            }
        }
        return false
    }
    
    private func translateKoreanLocationToEnglish(_ koreanLocation: String) -> String {
        let locationMap: [String: String] = [
            "포항시": "Pohang", "포항": "Pohang",
            "서울특별시": "Seoul", "서울시": "Seoul", "서울": "Seoul",
            "부산광역시": "Busan", "부산시": "Busan", "부산": "Busan",
            "대구광역시": "Daegu", "대구시": "Daegu", "대구": "Daegu",
            "인천광역시": "Incheon", "인천시": "Incheon", "인천": "Incheon",
            "광주광역시": "Gwangju", "광주시": "Gwangju", "광주": "Gwangju",
            "대전광역시": "Daejeon", "대전시": "Daejeon", "대전": "Daejeon",
            "울산광역시": "Ulsan", "울산시": "Ulsan", "울산": "Ulsan",
            "경상북도": "Gyeongsangbuk-do",
            "경주시": "Gyeongju", "경주": "Gyeongju",
            "안동시": "Andong", "안동": "Andong",
            "구미시": "Gumi", "구미": "Gumi",
            "강남구": "Gangnam-gu", "강동구": "Gangdong-gu",
            "종로구": "Jongno-gu", "중구": "Jung-gu"
        ]
        
        return locationMap[koreanLocation] ?? koreanLocation
    }
    
    // MARK: - Error Handling
    
    private func showLocationError() {
        isLoading = false
        locationName = NSLocalizedString("Location Failed", comment: "Location failed text")
        temperature = "?"
        condition = NSLocalizedString("Location permission required", comment: "Location permission required text")
        weatherIcon = "location.slash"
        iconColor = .red
    }
    
    private func showWeatherError() {
        isLoading = false
        temperature = "?"
        condition = NSLocalizedString("Unable to fetch weather data", comment: "Weather fetch error text")
        weatherIcon = "exclamationmark.triangle"
        iconColor = .orange
    }
    
    // MARK: - Weather Icons & Text
    
    private func weatherIconInfo(for condition: WeatherCondition) -> (icon: String, color: Color) {
        switch condition {
        case .clear, .mostlyClear:
            return ("sun.max.fill", .orange)
        case .partlyCloudy:
            return ("cloud.sun.fill", .blue)
        case .mostlyCloudy, .cloudy:
            return ("cloud.fill", .gray)
        case .foggy:
            return ("cloud.fog.fill", .secondary)
        case .drizzle:
            return ("cloud.drizzle.fill", .blue)
        case .rain:
            return ("cloud.rain.fill", .blue)
        case .heavyRain:
            return ("cloud.heavyrain.fill", .blue)
        case .snow:
            return ("cloud.snow.fill", .cyan)
        case .sleet:
            return ("cloud.sleet.fill", .cyan)
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms:
            return ("cloud.bolt.fill", .purple)
        case .strongStorms:
            return ("cloud.bolt.rain.fill", .purple)
        case .blizzard, .blowingSnow:
            return ("wind.snow", .cyan)
        case .freezingDrizzle, .freezingRain, .wintryMix:
            return ("cloud.sleet.fill", .cyan)
        case .frigid:
            return ("thermometer.snowflake", .cyan)
        case .hail:
            return ("cloud.hail.fill", .blue)
        case .hot:
            return ("thermometer.sun.fill", .red)
        case .hurricane:
            return ("hurricane", .purple)
        case .tropicalStorm:
            return ("tornado", .purple)
        case .windy:
            return ("wind", .secondary)
        @unknown default:
            return ("questionmark", .secondary)
        }
    }
    
    private func weatherConditionText(for condition: WeatherCondition) -> String {
        switch condition {
        case .clear:
            return NSLocalizedString("Clear", comment: "Weather condition: clear")
        case .mostlyClear:
            return NSLocalizedString("Mostly Clear", comment: "Weather condition: mostly clear")
        case .partlyCloudy:
            return NSLocalizedString("Partly Cloudy", comment: "Weather condition: partly cloudy")
        case .mostlyCloudy:
            return NSLocalizedString("Mostly Cloudy", comment: "Weather condition: mostly cloudy")
        case .cloudy:
            return NSLocalizedString("Cloudy", comment: "Weather condition: cloudy")
        case .foggy:
            return NSLocalizedString("Foggy", comment: "Weather condition: foggy")
        case .drizzle:
            return NSLocalizedString("Drizzle", comment: "Weather condition: drizzle")
        case .rain:
            return NSLocalizedString("Rain", comment: "Weather condition: rain")
        case .heavyRain:
            return NSLocalizedString("Heavy Rain", comment: "Weather condition: heavy rain")
        case .snow:
            return NSLocalizedString("Snow", comment: "Weather condition: snow")
        case .sleet:
            return NSLocalizedString("Sleet", comment: "Weather condition: sleet")
        case .thunderstorms:
            return NSLocalizedString("Thunderstorms", comment: "Weather condition: thunderstorms")
        case .windy:
            return NSLocalizedString("Windy", comment: "Weather condition: windy")
        case .hot:
            return NSLocalizedString("Hot", comment: "Weather condition: hot")
        default:
            return NSLocalizedString("Unknown Weather", comment: "Weather condition: unknown")
        }
    }
}

struct CalendarView: View {
    @State private var selectedDate: Date
    @State private var displayDate: Date
    @StateObject private var weatherManager: SimpleWeatherManager
    
    init() {
        let today = Date()
        _selectedDate = State(initialValue: today)
        _displayDate = State(initialValue: today)
        _weatherManager = StateObject(wrappedValue: SimpleWeatherManager())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            VStack(spacing: 8) {
                HStack {
                    Button(action: previousMonth) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    Text(monthYearString)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: nextMonth) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)

                // 요일 헤더
                HStack(spacing: 0) {
                    ForEach(weekdaySymbols, id: \.self) { day in
                        Text(day)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 8)
            }
            
            // 캘린더 그리드
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(calendarDays, id: \.self) { date in
                    if let date = date {
                        DayView(
                            date: date,
                            isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                            isToday: Calendar.current.isDate(date, inSameDayAs: Date()),
                            isCurrentMonth: Calendar.current.isDate(date, equalTo: displayDate, toGranularity: .month)
                        ) {
                            selectedDate = date
                            weatherManager.loadWeatherForDate(date)
                        }
                    } else {
                        Text("")
                            .frame(height: 32)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
            
            // 날씨 정보
            VStack(spacing: 0) {
                Divider()
                    .padding(.bottom, 10)
                
                // 위치 정보
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    
                    Text(weatherManager.locationName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: {
                        weatherManager.requestLocation()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Refresh weather")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                
                // 날씨 상세 정보
                HStack(spacing: 12) {
                    if weatherManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 18, height: 18)
                    } else if !weatherManager.weatherIcon.isEmpty {
                        Image(systemName: weatherManager.weatherIcon)
                            .foregroundColor(weatherManager.iconColor)
                            .font(.system(size: 18))
                            .frame(width: 20, height: 20)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(weatherManager.temperature)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text(weatherManager.condition)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        // Apple Weather 출처 표시
                        Button(action: {
                            if let url = URL(string: "https://weatherkit.apple.com/legal-attribution.html") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary.opacity(0.6))
                                
                                Text("Weather data by Apple Weather")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary.opacity(0.6))
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("View Apple Weather legal attribution")
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .frame(width: 280, height: 340)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.top, 4)
    }
    
    // MARK: - Calendar Logic
    
    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.shortWeekdaySymbols
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "yyyyMMMM", options: 0, locale: Locale.current)
        return formatter.string(from: displayDate)
    }
    
    private var calendarDays: [Date?] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: displayDate)?.start ?? displayDate
        let endOfMonth = calendar.dateInterval(of: .month, for: displayDate)?.end ?? displayDate
        let startOfCalendar = calendar.dateInterval(of: .weekOfYear, for: startOfMonth)?.start ?? startOfMonth
        
        var days: [Date?] = []
        var currentDate = startOfCalendar
        
        while days.count < 42 {
            if currentDate < startOfMonth || currentDate >= endOfMonth {
                days.append(nil)
            } else {
                days.append(currentDate)
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return days
    }
    
    private func previousMonth() {
        displayDate = Calendar.current.date(byAdding: .month, value: -1, to: displayDate) ?? displayDate
    }
    
    private func nextMonth() {
        displayDate = Calendar.current.date(byAdding: .month, value: 1, to: displayDate) ?? displayDate
    }
}

struct DayView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 13))
                .foregroundColor(textColor)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(backgroundColor)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 32, height: 32)
        .contentShape(Rectangle())
//        .border(Color.gray)
    }
    
    private var textColor: Color {
        if !isCurrentMonth {
            return .clear
        } else if isSelected {
            return .white
        } else if isToday {
            return .accentColor
        } else {
            return .primary
        }
    }
    
    private var backgroundColor: Color {
        if !isCurrentMonth {
            return .clear
        } else if isSelected {
            return .accentColor
        } else if isToday {
            return Color.accentColor.opacity(0.1)
        } else {
            return .clear
        }
    }
}

struct ContentView: View {
    var body: some View {
        CalendarView()
    }
}

#Preview {
    ContentView()
}
