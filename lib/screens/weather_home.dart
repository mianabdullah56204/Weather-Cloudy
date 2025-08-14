import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WeatherHome extends StatefulWidget {
  const WeatherHome({super.key});

  @override
  State<WeatherHome> createState() => _WeatherHomeState();
}

class _WeatherHomeState extends State<WeatherHome> {
  final TextEditingController _cityController = TextEditingController();

  String? _cityName;
  String? _temperature;
  String? _weatherDescription;
  IconData? _weatherMaterialIcon;
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _citySuggestions = [
    "London",
    "New York",
    "Paris",
    "Tokyo",
    "Delhi",
    "Sydney",
    "Moscow",
    "Dubai",
    "Singapore",
    "Toronto",
    "Los Angeles",
    "Berlin",
    "Chicago",
    "Madrid",
    "Rome",
    "Karachi",
    "Lahore",
    "Islamabad",
    "Mumbai",
    "Bahawalpur",
    "Multan",
    "Islamabad",
    "Rawalpindi",
    "Faisalabad",
    "Peshawar",
    "Quetta",
    "Hyderabad",
    "Gujranwala",
    "Sialkot",
  ];

  List<String> _filteredSuggestions = [];
  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  void _updateSuggestions(String input) {
    if (input.isEmpty) {
      setState(() => _filteredSuggestions = []);
      return;
    }
    setState(() {
      _filteredSuggestions = _citySuggestions
          .where((city) => city.toLowerCase().startsWith(input.toLowerCase()))
          .toList();
    });
  }

  Future<({String name, double lat, double lon})?> _geocodeCity(
    String city,
  ) async {
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': city.trim(),
      'count': '1',
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final jsonBody = json.decode(res.body);
    if (jsonBody is! Map ||
        jsonBody['results'] == null ||
        (jsonBody['results'] as List).isEmpty) {
      return null;
    }
    final r = (jsonBody['results'] as List).first as Map;
    final nameParts = [
      if (r['name'] != null) r['name'],
      if (r['admin1'] != null) r['admin1'],
      if (r['country'] != null) r['country'],
    ].whereType<String>().toList();
    return (
      name: nameParts.join(', '),
      lat: (r['latitude'] as num).toDouble(),
      lon: (r['longitude'] as num).toDouble(),
    );
  }

  Future<void> _fetchFromOpenMeteo(String city) async {
    final geo = await _geocodeCity(city);
    if (geo == null) {
      setState(() => _errorMessage = 'City not found.');
      return;
    }

    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': geo.lat.toString(),
      'longitude': geo.lon.toString(),
      'current': 'temperature_2m,weather_code,relative_humidity_2m',
      'timezone': 'auto',
      'forecast_days': '1',
    });

    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      setState(() => _errorMessage = 'Failed to fetch weather from Open‑Meteo');
      return;
    }

    final data = json.decode(res.body) as Map;
    final current = (data['current'] ?? {}) as Map;
    final temp = (current['temperature_2m'] as num?)?.toDouble();
    final code = (current['weather_code'] as num?)?.toInt();

    setState(() {
      _cityName = geo.name;
      _temperature = temp?.toStringAsFixed(1);
      _weatherDescription = _omCodeToText(code);
      _weatherMaterialIcon = _omCodeToIcon(code);
    });
  }

  Future<void> _fetchWeather(String city) async {
    final trimmed = city.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _errorMessage = "Please enter a city name";
        _cityName = null;
        _filteredSuggestions = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _cityName = null;
      _temperature = null;
      _weatherDescription = null;
      _weatherMaterialIcon = null;
      _filteredSuggestions = [];
    });

    try {
      await _fetchFromOpenMeteo(trimmed);
    } on TimeoutException {
      setState(() => _errorMessage = "Request timed out. Try again.");
    } on http.ClientException {
      setState(() => _errorMessage = "Network error. Check your connection.");
    } catch (e) {
      setState(() => _errorMessage = "Failed to load weather data.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _omCodeToText(int? code) {
    if (code == null) return 'Unknown';
    if ({0}.contains(code)) return 'Clear sky';
    if ({1}.contains(code)) return 'Mainly clear';
    if ({2}.contains(code)) return 'Partly cloudy';
    if ({3}.contains(code)) return 'Overcast';
    if ({45, 48}.contains(code)) return 'Fog';
    if ({51, 53, 55}.contains(code)) return 'Drizzle';
    if ({61, 63, 65}.contains(code)) return 'Rain';
    if ({66, 67}.contains(code)) return 'Freezing rain';
    if ({71, 73, 75, 77}.contains(code)) return 'Snow';
    if ({80, 81, 82}.contains(code)) return 'Rain showers';
    if ({85, 86}.contains(code)) return 'Snow showers';
    if ({95}.contains(code)) return 'Thunderstorm';
    if ({96, 97}.contains(code)) return 'Thunderstorm w/ hail';
    return 'Unknown';
  }

  IconData _omCodeToIcon(int? code) {
    if (code == null) return Icons.help_outline;
    if ({0, 1}.contains(code)) return Icons.wb_sunny_outlined;
    if ({2}.contains(code)) return Icons.cloud_queue;
    if ({3}.contains(code)) return Icons.cloud;
    if ({45, 48}.contains(code)) return Icons.dehaze;
    if ({51, 53, 55, 61, 63, 65, 80, 81, 82}.contains(code)) return Icons.grain;
    if ({66, 67}.contains(code)) return Icons.ac_unit;
    if ({71, 73, 75, 77, 85, 86}.contains(code)) return Icons.ac_unit;
    if ({95, 96, 97}.contains(code)) return Icons.thunderstorm;
    return Icons.device_thermostat;
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      labelText: "Enter City Name",
      labelStyle: TextStyle(color: Colors.white),
      hintText: "e.g. bahawalpur, lahore",
      hintStyle: TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white.withOpacity(0.2),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white, width: 1.5),
      ),
      prefixIcon: Icon(Icons.location_city, color: Colors.white),
      suffixIcon: IconButton(
        icon: Icon(Icons.search, color: Colors.white),
        onPressed: () {
          _fetchWeather(_cityController.text.trim());
          FocusScope.of(context).unfocus();
        },
      ),
      contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1976D2), Color(0xFF2196F3), Color(0xFF64B5F6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Weather",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Search for a city to see the weather",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 40),
                    Stack(
                      children: [
                        TextField(
                          controller: _cityController,
                          cursorColor: Colors.white,
                          decoration: _inputDecoration(),
                          style: TextStyle(color: Colors.white),
                          onChanged: _updateSuggestions,
                          onSubmitted: (value) {
                            _fetchWeather(value.trim());
                            FocusScope.of(context).unfocus();
                          },
                        ),
                        if (_filteredSuggestions.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 65.0),
                            child: Container(
                              height: (_filteredSuggestions.length * 55.0)
                                  .clamp(0, 220.0),
                              decoration: BoxDecoration(
                                color: Color(0xFF1976D2).withOpacity(0.9),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: _filteredSuggestions.length,
                                itemBuilder: (context, index) {
                                  final suggestion =
                                      _filteredSuggestions[index];
                                  return ListTile(
                                    title: Text(
                                      suggestion,
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    onTap: () {
                                      _cityController.text = suggestion;
                                      setState(() => _filteredSuggestions = []);
                                      _fetchWeather(suggestion);
                                      FocusScope.of(context).unfocus();
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: _isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : _errorMessage != null
                        ? Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          )
                        : _cityName == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 60,
                                color: Colors.white.withOpacity(0.7),
                              ),
                              SizedBox(height: 16),
                              Text(
                                "Search for a city to see the weather",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          )
                        : Container(
                            height: 400,
                            padding: EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.2),
                                  Colors.white.withOpacity(0.1),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 15,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                if (_weatherMaterialIcon != null)
                                  Icon(
                                    _weatherMaterialIcon,
                                    size: 80,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                SizedBox(height: 20),
                                Text(
                                  _cityName!,
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  _temperature != null
                                      ? "$_temperature°C"
                                      : "—",
                                  style: TextStyle(
                                    fontSize: 64,
                                    fontWeight: FontWeight.w300,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  (_weatherDescription == null ||
                                          _weatherDescription!.isEmpty)
                                      ? '—'
                                      : _weatherDescription![0].toUpperCase() +
                                            _weatherDescription!.substring(1),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
