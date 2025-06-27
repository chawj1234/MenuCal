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

// 간단한 날씨 매니저
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
    private var selectedDate: Date = Date() // 현재 선택된 날짜 추적
    
    override init() {
        print("🚀 [Init] SimpleWeatherManager 초기화 시작")
        super.init()
        setupLocationManager()
        requestLocation()
        print("🚀 [Init] SimpleWeatherManager 초기화 완료")
    }
    
    private func setupLocationManager() {
        print("⚙️ [Setup] LocationManager 설정 시작")
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        print("⚙️ [Setup] LocationManager 설정 완료 - 정확도: \(locationManager.desiredAccuracy)")
    }
    
    func requestLocation() {
        print("🚀 [Location] 위치 정보 요청 시작")
        isLoading = true
        locationName = NSLocalizedString("Locating...", comment: "Location loading text")
        
        // 기존 위치 정보 초기화
        currentLocation = nil
        
        locationManager.requestLocation()
    }
    
    // CLLocationManagerDelegate 메서드들
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            print("❌ [Location] 위치 정보 없음")
            return
        }
        
        print("🔍 [Location] 위치 업데이트: (\(location.coordinate.latitude), \(location.coordinate.longitude))")
        currentLocation = location
        
        // 현재 선택된 날짜의 날씨 로드
        loadWeather(for: location, date: selectedDate)
        
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ [Location] 위치 가져오기 실패: \(error.localizedDescription)")
        print("❌ [Location] 에러 타입: \(type(of: error))")
        if let clError = error as? CLError {
            print("❌ [Location] CLError 코드: \(clError.code.rawValue)")
        }
        showLocationError()
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        print("🔍 [Location] 권한 상태 변경: \(authStatusString(status))")
        
        switch status {
        case .notDetermined:
            print("🔍 [Location] 권한 미결정 -> 권한 요청")
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            print("🔍 [Location] 권한 승인됨 -> 위치 요청")
            locationManager.requestLocation()
        case .denied, .restricted:
            print("🔍 [Location] 권한 거부됨 -> 에러 표시")
            showLocationError()
        default:
            print("🔍 [Location] 대기 중...")
            break
        }
    }
    
    // 권한 상태를 문자열로 변환하는 헬퍼 함수
    private func authStatusString(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "notDetermined"
        case .restricted:
            return "restricted"
        case .denied:
            return "denied"
        case .authorizedAlways:
            return "authorizedAlways"
        case .authorizedWhenInUse:
            return "authorizedWhenInUse"
        @unknown default:
            return "unknown"
        }
    }
    
    // 위치 에러 표시
    private func showLocationError() {
        isLoading = false
        locationName = NSLocalizedString("Location Failed", comment: "Location failed text")
        temperature = "?"
        condition = NSLocalizedString("Location permission required", comment: "Location permission required text")
        weatherIcon = "location.slash"
        iconColor = .red
    }
    
    // 날씨 에러 표시
    private func showWeatherError() {
        isLoading = false
        temperature = "?"
        condition = NSLocalizedString("Unable to fetch weather data", comment: "Weather fetch error text")
        weatherIcon = "exclamationmark.triangle"
        iconColor = .orange
    }
    
    // 선택된 날짜의 날씨 가져오기
    func loadWeatherForDate(_ date: Date) {
        selectedDate = date // 선택된 날짜 저장
        guard let location = currentLocation else {
            print("❌ [Weather] 현재 위치 정보 없음")
            showLocationError()
            return
        }
        
        loadWeather(for: location, date: date)
    }
    
    private func loadWeather(for location: CLLocation, date: Date) {
        print("🌤️ [Weather] loadWeather 시작 - 위치: (\(location.coordinate.latitude), \(location.coordinate.longitude))")
        isLoading = true
        
        Task {
            do {
                print("🌤️ [Weather] WeatherKit API 호출 중...")
                let weather = try await weatherService.weather(for: location)
                print("🌤️ [Weather] WeatherKit API 호출 성공")
                
                // dailyForecast에 있는 모든 날짜 확인
                print("🌤️ [Weather] dailyForecast 데이터 분석:")
                for (index, forecast) in weather.dailyForecast.enumerated() {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    print("🌤️ [Weather] dailyForecast[\(index)]: \(dateFormatter.string(from: forecast.date)) (\(forecast.condition.description))")
                }
                
                // 오늘인지 미래 날짜인지 확인
                let isToday = Calendar.current.isDate(date, inSameDayAs: Date())
                let isFutureDate = date > Date()
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                print("🌤️ [Weather] 선택된 날짜: \(dateFormatter.string(from: date)) - 오늘: \(isToday), 미래: \(isFutureDate)")
                
                if isToday {
                    // 오늘 날씨 (현재 날씨)
                    print("🌤️ [Weather] 현재 날씨 적용 - 온도: \(weather.currentWeather.temperature.value)°")
                    updateWeatherUI(
                        temperature: Int(weather.currentWeather.temperature.value),
                        condition: weather.currentWeather.condition,
                        date: date
                    )
                } else {
                    // 과거 또는 미래 날짜 - dailyForecast에서 찾기
                    if let dailyForecast = weather.dailyForecast.first(where: { forecast in
                        Calendar.current.isDate(forecast.date, inSameDayAs: date)
                    }) {
                        let avgTemp = (dailyForecast.highTemperature.value + dailyForecast.lowTemperature.value) / 2
                        let dateType = isFutureDate ? "미래 예보" : "과거 기록"
                        print("🌤️ [Weather] \(dateType) 날씨 적용 - 고온: \(dailyForecast.highTemperature.value)°, 저온: \(dailyForecast.lowTemperature.value)°, 평균: \(avgTemp)°")
                        updateWeatherUI(
                            temperature: Int(avgTemp),
                            condition: dailyForecast.condition,
                            date: date
                        )
                    } else {
                        // 데이터가 없는 경우 - 과거/미래에 따라 다른 메시지
                        let dateType = isFutureDate ? "예보" : "과거 기록"
                        print("🌤️ [Weather] \(dateType) 데이터 없음")
                        self.temperature = ""
                        self.condition = isFutureDate ? 
                            NSLocalizedString("Forecast data is not available yet", comment: "Forecast data not available") :
                            NSLocalizedString("We don't have data for past weather.", comment: "Past weather data not available")
                        self.weatherIcon = "calendar.badge.clock"
                        self.iconColor = .secondary
                        self.isLoading = false
                    }
                }
                
                        // 위치명 가져오기 (처음 한 번만)
        if locationName == NSLocalizedString("Locating...", comment: "Location loading text") {
            print("🌤️ [Weather] 위치명 역지오코딩 시작")
            getLocationName(for: location)
        }
                
                self.isLoading = false
                print("🌤️ [Weather] loadWeather 완료")
            } catch {
                print("❌ [Weather] WeatherKit API 실패: \(error.localizedDescription)")
                print("❌ [Weather] 에러 타입: \(type(of: error))")
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
    
    private func getLocationName(for location: CLLocation) {
        print("📍 [Geocoding] 역지오코딩 시작 - 위치: (\(location.coordinate.latitude), \(location.coordinate.longitude))")
        let geocoder = CLGeocoder()
        
        // 시스템 언어에 맞는 로케일로 위치명 요청
        let systemLanguage = Locale.current.languageCode ?? "en"
        let preferredLocale = Locale(identifier: systemLanguage)
        
        print("📍 [Geocoding] 시스템 언어: \(systemLanguage), 사용할 로케일: \(preferredLocale.identifier)")
        
        if #available(macOS 11.0, *) {
            geocoder.reverseGeocodeLocation(location, preferredLocale: preferredLocale) { [weak self] placemarks, error in
                self?.handleGeocodeResult(placemarks: placemarks, error: error)
            }
        } else {
            // macOS 11 미만에서는 기본 로케일 사용
            geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
                self?.handleGeocodeResult(placemarks: placemarks, error: error)
            }
        }
    }
    
    private func handleGeocodeResult(placemarks: [CLPlacemark]?, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                print("❌ [Geocoding] 역지오코딩 실패: \(error.localizedDescription)")
                self.locationName = NSLocalizedString("Current Location", comment: "Current location text")
                return
            }
            
            if let placemark = placemarks?.first {
                let originalLocationName = placemark.locality ?? 
                                          placemark.administrativeArea ?? 
                                          NSLocalizedString("Current Location", comment: "Current location text")
                
                // 시스템 언어가 영어인데 한국어 위치명이 나온 경우 영어로 변환
                let systemLanguage = Locale.current.languageCode ?? "en"
                let finalLocationName: String
                
                if systemLanguage == "en" && self.containsKorean(originalLocationName) {
                    finalLocationName = self.translateKoreanLocationToEnglish(originalLocationName)
                    print("📍 [Geocoding] 한국어 위치명을 영어로 변환: \(originalLocationName) -> \(finalLocationName)")
                } else {
                    finalLocationName = originalLocationName
                    print("📍 [Geocoding] 위치명 사용: \(finalLocationName)")
                }
                
                self.locationName = finalLocationName
            } else {
                print("📍 [Geocoding] 위치명 정보 없음")
                self.locationName = NSLocalizedString("Current Location", comment: "Current location text")
            }
        }
    }
    
    // 한국어 문자가 포함되어 있는지 확인
    private func containsKorean(_ text: String) -> Bool {
        for character in text {
            let scalar = character.unicodeScalars.first
            if let scalar = scalar,
               (scalar.value >= 0xAC00 && scalar.value <= 0xD7AF) || // 한글 완성형
               (scalar.value >= 0x1100 && scalar.value <= 0x11FF) || // 한글 자모
               (scalar.value >= 0x3130 && scalar.value <= 0x318F) || // 한글 호환 자모
               (scalar.value >= 0xA960 && scalar.value <= 0xA97F) {   // 한글 확장 A
                return true
            }
        }
        return false
    }
    
    // 한국어 위치명을 영어로 변환
    private func translateKoreanLocationToEnglish(_ koreanLocation: String) -> String {
        let locationMap: [String: String] = [
            // 주요 도시
            "포항시": "Pohang",
            "포항": "Pohang",
            "서울특별시": "Seoul",
            "서울시": "Seoul",
            "서울": "Seoul",
            "부산광역시": "Busan",
            "부산시": "Busan",
            "부산": "Busan",
            "대구광역시": "Daegu",
            "대구시": "Daegu",
            "대구": "Daegu",
            "인천광역시": "Incheon",
            "인천시": "Incheon",
            "인천": "Incheon",
            "광주광역시": "Gwangju",
            "광주시": "Gwangju",
            "광주": "Gwangju",
            "대전광역시": "Daejeon",
            "대전시": "Daejeon",
            "대전": "Daejeon",
            "울산광역시": "Ulsan",
            "울산시": "Ulsan",
            "울산": "Ulsan",
            
            // 경상북도 주요 도시
            "경상북도": "Gyeongsangbuk-do",
            "경주시": "Gyeongju",
            "경주": "Gyeongju",
            "안동시": "Andong",
            "안동": "Andong",
            "구미시": "Gumi",
            "구미": "Gumi",
            "영주시": "Yeongju",
            "영주": "Yeongju",
            "김천시": "Gimcheon",
            "김천": "Gimcheon",
            "상주시": "Sangju",
            "상주": "Sangju",
            "문경시": "Mungyeong",
            "문경": "Mungyeong",
            
            // 기타 도
            "경기도": "Gyeonggi-do",
            "강원도": "Gangwon-do",
            "충청북도": "Chungcheongbuk-do",
            "충청남도": "Chungcheongnam-do",
            "전라북도": "Jeollabuk-do",
            "전라남도": "Jeollanam-do",
            "경상남도": "Gyeongsangnam-do",
            "제주특별자치도": "Jeju-do",
            "제주도": "Jeju-do",
            "제주": "Jeju",
            
            // 서울 구
            "강남구": "Gangnam-gu",
            "강동구": "Gangdong-gu",
            "강북구": "Gangbuk-gu",
            "강서구": "Gangseo-gu",
            "관악구": "Gwanak-gu",
            "광진구": "Gwangjin-gu",
            "구로구": "Guro-gu",
            "금천구": "Geumcheon-gu",
            "노원구": "Nowon-gu",
            "도봉구": "Dobong-gu",
            "동대문구": "Dongdaemun-gu",
            "동작구": "Dongjak-gu",
            "마포구": "Mapo-gu",
            "서대문구": "Seodaemun-gu",
            "서초구": "Seocho-gu",
            "성동구": "Seongdong-gu",
            "성북구": "Seongbuk-gu",
            "송파구": "Songpa-gu",
            "양천구": "Yangcheon-gu",
            "영등포구": "Yeongdeungpo-gu",
            "용산구": "Yongsan-gu",
            "은평구": "Eunpyeong-gu",
            "종로구": "Jongno-gu",
            "중구": "Jung-gu",
            "중랑구": "Jungnang-gu"
        ]
        
        // 매핑에서 찾아서 반환, 없으면 원본 반환
        return locationMap[koreanLocation] ?? koreanLocation
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
//                .padding(.top, 8)
                
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
            .background(Color.clear)
            
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
                    } else {
                        Image(systemName: weatherManager.weatherIcon)
                            .foregroundColor(weatherManager.iconColor)
                            .font(.system(size: 18))
                            .frame(width: 20, height: 20)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
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
            return .secondary
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
