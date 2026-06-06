import 'package:chart_model/chart_model.dart';

const testExpression = ChartExpression(
  planets: [
    Planet(id: 'sun', name: 'Sun', longitude: 135.5, sign: 'Leo', signIndex: 4, degreeInSign: 15.5, retrograde: false, nakshatra: 'Magha', nakshatraPada: 2, house: 1),
    Planet(id: 'moon', name: 'Moon', longitude: 45.2, sign: 'Taurus', signIndex: 1, degreeInSign: 15.2, retrograde: false, nakshatra: 'Rohini', nakshatraPada: 3, house: 10),
    Planet(id: 'mars', name: 'Mars', longitude: 200.0, sign: 'Libra', signIndex: 6, degreeInSign: 20.0, retrograde: true, nakshatra: 'Swati', nakshatraPada: 1, house: 3),
  ],
  ascendant: Ascendant(signIndex: 4, longitude: 130.0),
  houses: [
    House(number: 1, signIndex: 4, cuspLongitude: 130.0),
    House(number: 2, signIndex: 5, cuspLongitude: 160.0),
    House(number: 3, signIndex: 6, cuspLongitude: 190.0),
    House(number: 4, signIndex: 7, cuspLongitude: 220.0),
    House(number: 5, signIndex: 8, cuspLongitude: 250.0),
    House(number: 6, signIndex: 9, cuspLongitude: 280.0),
    House(number: 7, signIndex: 10, cuspLongitude: 310.0),
    House(number: 8, signIndex: 11, cuspLongitude: 340.0),
    House(number: 9, signIndex: 0, cuspLongitude: 10.0),
    House(number: 10, signIndex: 1, cuspLongitude: 40.0),
    House(number: 11, signIndex: 2, cuspLongitude: 70.0),
    House(number: 12, signIndex: 3, cuspLongitude: 100.0),
  ],
);
