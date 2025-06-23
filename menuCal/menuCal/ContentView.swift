//
//  ContentView.swift
//  menuCal
//
//  Created by 차원준 on 6/23/25.
//

import SwiftUI
import WeatherKit
import CoreLocation

// 간단한 날씨 매니저
@MainActor
class SimpleWeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var temperature: String = "25°"
    @Published var condition: String = "맑음"
    @Published var weatherIcon: String = "sun.max.fill"
    @Published var iconColor: Color = .orange
    @Published var locationName: String = NSLocalizedString("Locating...", comment: "Location loading text")
    @Published var isLoading = false
    
    private let weatherService = WeatherService.shared
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    
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
        locationName = "위치 확인 중..."
        
        // 위치 권한 확인 및 요청
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            // 권한이 거부된 경우 서울 날씨로 폴백
            loadSeoulWeather()
        @unknown default:
            loadSeoulWeather()
        }
    }
    
    // CLLocationManagerDelegate 메서드들
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            loadSeoulWeather()
            return
        }
        
        currentLocation = location
        loadWeather(for: location, date: Date())
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("위치 가져오기 실패: \(error.localizedDescription)")
        loadSeoulWeather()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            loadSeoulWeather()
        default:
            break
        }
    }
    
    // 선택된 날짜의 날씨 가져오기
    func loadWeatherForDate(_ date: Date) {
        guard let location = currentLocation else {
            loadSeoulWeatherForDate(date)
            return
        }
        
        loadWeather(for: location, date: date)
    }
    
    private func loadWeather(for location: CLLocation, date: Date) {
        isLoading = true
        
        Task {
            do {
                let weather = try await weatherService.weather(for: location)
                
                // 오늘인지 미래 날짜인지 확인
                let isToday = Calendar.current.isDate(date, inSameDayAs: Date())
                let isFutureDate = date > Date()
                
                if isToday {
                    // 오늘 날씨 (현재 날씨)
                    updateWeatherUI(
                        temperature: Int(weather.currentWeather.temperature.value),
                        condition: weather.currentWeather.condition,
                        date: date
                    )
                } else if isFutureDate {
                    // 미래 날짜 예보
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
                        // 예보 데이터가 없는 경우
                        self.temperature = "?"
                        self.condition = NSLocalizedString("No Forecast", comment: "No weather forecast available")
                        self.weatherIcon = "questionmark"
                        self.iconColor = .secondary
                    }
                } else {
                    // 과거 날짜 (현재 날씨로 대체)
                    updateWeatherUI(
                        temperature: Int(weather.currentWeather.temperature.value),
                        condition: weather.currentWeather.condition,
                        date: date
                    )
                }
                
                // 위치명 가져오기 (처음 한 번만)
                if locationName == NSLocalizedString("Locating...", comment: "Location loading text") {
                    getLocationName(for: location)
                }
                
                self.isLoading = false
            } catch {
                print("날씨 가져오기 실패: \(error.localizedDescription)")
                // WeatherKit 실패 시 서울로 폴백
                loadSeoulWeatherForDate(date)
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
    
    private func loadSeoulWeather() {
        loadSeoulWeatherForDate(Date())
    }
    
    private func loadSeoulWeatherForDate(_ date: Date) {
        locationName = NSLocalizedString("Seoul", comment: "Seoul city name")
        let seoulLocation = CLLocation(latitude: 37.5665, longitude: 126.9780)
        currentLocation = seoulLocation
        
        Task {
            do {
                let weather = try await weatherService.weather(for: seoulLocation)
                
                let isToday = Calendar.current.isDate(date, inSameDayAs: Date())
                let isFutureDate = date > Date()
                
                if isToday {
                    updateWeatherUI(
                        temperature: Int(weather.currentWeather.temperature.value),
                        condition: weather.currentWeather.condition,
                        date: date
                    )
                } else if isFutureDate {
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
                        self.temperature = "?"
                        self.condition = NSLocalizedString("No Forecast", comment: "No weather forecast available")
                        self.weatherIcon = "questionmark"
                        self.iconColor = .secondary
                    }
                } else {
                    updateWeatherUI(
                        temperature: Int(weather.currentWeather.temperature.value),
                        condition: weather.currentWeather.condition,
                        date: date
                    )
                }
                
                self.isLoading = false
            } catch {
                // 최후의 폴백
                self.temperature = "25°"
                self.condition = NSLocalizedString("Clear", comment: "Weather condition: clear")
                self.weatherIcon = "sun.max.fill"
                self.iconColor = .orange
                self.isLoading = false
            }
        }
    }
    
    private func getLocationName(for location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first {
                    self?.locationName = placemark.locality ?? 
                                       placemark.administrativeArea ?? 
                                       NSLocalizedString("Current Location", comment: "Current location text")
                } else {
                    self?.locationName = NSLocalizedString("Current Location", comment: "Current location text")
                }
            }
        }
    }
    
    func refreshWeather() {
        requestLocation()
    }
    
    // 날씨 상태에 따른 아이콘과 색상 정보
    private func weatherIconInfo(for condition: WeatherCondition) -> (icon: String, color: Color) {
        switch condition {
        case .clear:
            return ("sun.max.fill", .orange)
        case .mostlyClear:
            return ("sun.max.fill", .orange)
        case .partlyCloudy:
            return ("cloud.sun.fill", .blue)
        case .mostlyCloudy:
            return ("cloud.fill", .gray)
        case .cloudy:
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
        case .thunderstorms:
            return ("cloud.bolt.rain.fill", .purple)
        case .blizzard:
            return ("wind.snow", .cyan)
        case .blowingSnow:
            return ("wind.snow", .cyan)
        case .freezingDrizzle:
            return ("cloud.sleet.fill", .cyan)
        case .freezingRain:
            return ("cloud.sleet.fill", .cyan)
        case .frigid:
            return ("thermometer.snowflake", .cyan)
        case .hail:
            return ("cloud.hail.fill", .blue)
        case .hot:
            return ("thermometer.sun.fill", .red)
        case .hurricane:
            return ("hurricane", .purple)
        case .isolatedThunderstorms:
            return ("cloud.bolt.fill", .purple)
        case .scatteredThunderstorms:
            return ("cloud.bolt.fill", .purple)
        case .strongStorms:
            return ("cloud.bolt.rain.fill", .purple)
        case .tropicalStorm:
            return ("tornado", .purple)
        case .windy:
            return ("wind", .secondary)
        case .wintryMix:
            return ("cloud.sleet.fill", .cyan)
        @unknown default:
            return ("questionmark", .secondary)
        }
    }
    
    // 날씨 상태 텍스트 (시스템 언어 따름)
    private func weatherConditionText(for condition: WeatherCondition) -> String {
        let formatter = MeasurementFormatter()
        formatter.locale = Locale.current
        
        // WeatherCondition을 시스템 언어로 변환
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
        case .blizzard:
            return NSLocalizedString("Blizzard", comment: "Weather condition: blizzard")
        case .blowingSnow:
            return NSLocalizedString("Blowing Snow", comment: "Weather condition: blowing snow")
        case .freezingDrizzle:
            return NSLocalizedString("Freezing Drizzle", comment: "Weather condition: freezing drizzle")
        case .freezingRain:
            return NSLocalizedString("Freezing Rain", comment: "Weather condition: freezing rain")
        case .frigid:
            return NSLocalizedString("Frigid", comment: "Weather condition: frigid")
        case .hail:
            return NSLocalizedString("Hail", comment: "Weather condition: hail")
        case .hot:
            return NSLocalizedString("Hot", comment: "Weather condition: hot")
        case .hurricane:
            return NSLocalizedString("Hurricane", comment: "Weather condition: hurricane")
        case .isolatedThunderstorms:
            return NSLocalizedString("Isolated Thunderstorms", comment: "Weather condition: isolated thunderstorms")
        case .scatteredThunderstorms:
            return NSLocalizedString("Scattered Thunderstorms", comment: "Weather condition: scattered thunderstorms")
        case .strongStorms:
            return NSLocalizedString("Strong Storms", comment: "Weather condition: strong storms")
        case .tropicalStorm:
            return NSLocalizedString("Tropical Storm", comment: "Weather condition: tropical storm")
        case .windy:
            return NSLocalizedString("Windy", comment: "Weather condition: windy")
        case .wintryMix:
            return NSLocalizedString("Wintry Mix", comment: "Weather condition: wintry mix")
        @unknown default:
            return NSLocalizedString("Unknown Weather", comment: "Weather condition: unknown")
        }
    }
}

struct CalendarView: View {
    @State private var selectedDate = Date()
    @State private var displayDate = Date()
    @StateObject private var weatherManager = SimpleWeatherManager()
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더 (월/년 네비게이션)
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
                .padding(.horizontal, 12)
                .padding(.top, 12)
                
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
                .padding(.horizontal, 12)
            }
            .background(Color(NSColor.controlBackgroundColor))
            
            // 캘린더 그리드
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 1) {
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
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            
            Divider()
            
            // 날씨 정보
            VStack(spacing: 4) {
                // 위치 정보
                HStack {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Text(weatherManager.locationName)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                HStack(spacing: 8) {
                    if weatherManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: weatherManager.weatherIcon)
                            .foregroundColor(weatherManager.iconColor)
                            .font(.system(size: 16))
                    }
                    
                    Text(weatherManager.temperature)
                        .font(.system(size: 14, weight: .medium))
                    
                    Text(weatherManager.condition)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(refreshButtonText) {
                        weatherManager.loadWeatherForDate(selectedDate)
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 280, height: 360)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Calendar Logic
    
    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.shortWeekdaySymbols
    }
    
    private var todayText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.current
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: Date(), relativeTo: Date())
    }
    
    private var tomorrowText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.current
        formatter.dateTimeStyle = .named
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return formatter.localizedString(for: tomorrow, relativeTo: Date())
    }
    
    private var yesterdayText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.current
        formatter.dateTimeStyle = .named
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return formatter.localizedString(for: yesterday, relativeTo: Date())
    }
    
    private var refreshButtonText: String {
        return NSLocalizedString("Refresh", comment: "Button to refresh weather data")
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "yyyyMMMM", options: 0, locale: Locale.current)
        return formatter.string(from: displayDate)
    }
    
    private var selectedDateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        
        if Calendar.current.isDate(selectedDate, inSameDayAs: Date()) {
            return todayText
        } else if Calendar.current.isDate(selectedDate, inSameDayAs: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()) {
            return tomorrowText
        } else if Calendar.current.isDate(selectedDate, inSameDayAs: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()) {
            return yesterdayText
        } else {
            formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "MMMdE", options: 0, locale: Locale.current)
            return formatter.string(from: selectedDate)
        }
    }
    
    private var calendarDays: [Date?] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: displayDate)?.start ?? displayDate
        let endOfMonth = calendar.dateInterval(of: .month, for: displayDate)?.end ?? displayDate
        
        let startOfCalendar = calendar.dateInterval(of: .weekOfYear, for: startOfMonth)?.start ?? startOfMonth
        
        var days: [Date?] = []
        var currentDate = startOfCalendar
        
        while days.count < 42 { // 6주 * 7일
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
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var textColor: Color {
        if !isCurrentMonth {
            return .clear
        } else if isSelected {
            return .white
        } else if isToday {
            return .blue
        } else {
            return .primary
        }
    }
    
    private var backgroundColor: Color {
        if !isCurrentMonth {
            return .clear
        } else if isSelected {
            return .blue
        } else if isToday {
            return Color.blue.opacity(0.1)
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
