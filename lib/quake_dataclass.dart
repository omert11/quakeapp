import 'package:intl/intl.dart';

class QuakeData {
  late double intensity;
  late double depth;
  late String location;
  late double latitude;
  late double longitude;
  late DateTime dateTime;
  QuakeData(
      {this.intensity = 0,
      this.depth = 0,
      this.location = "",
      this.latitude = 0,
      this.longitude = 0});
  QuakeData.fromRequest(Map<String, dynamic> json) {
    String target = json["title"].split("(")[1].split(")")[0];
    List<String> titleSplit = json["title"].split(" ($target)");
    String title = titleSplit[1];
    String dateString = title.substring(title.length - 19);
    title = title.split(dateString)[0];
    List<String> coordinates =
        json["description"].split("($target) ")[1].split(" ");
    intensity = double.parse(titleSplit[0]);
    depth = double.parse(coordinates[2]);
    location = title;
    latitude = double.parse(coordinates[0]);
    longitude = double.parse(coordinates[1]);
    dateTime = DateFormat("yyyy.MM.dd hh:mm:ss").parse(dateString);
  }
  QuakeData.fromSql(Map<String, dynamic> json) {
    intensity = json["intensity"];
    depth = json["depth"];
    location = json["location"];
    latitude = json["latitude"];
    longitude = json["longitude"];
    dateTime = DateFormat("yyyy.MM.dd hh:mm:ss").parse(json["dateTime"]);
  }
  get sqlDateTime => DateFormat("yyyy.MM.dd hh:mm:ss").format(dateTime);
}
/*{
  title: 2.6 (ML) GOKOVA KORFEZI (AKDENIZ) 2021.07.15 13:37:49,
  description: 2021.07.15 13:37:49 2.6 (ML) 36.8705 27.7143 1.8,
  link: http://www.koeri.boun.edu.tr/sismo/2/son-depremler/liste-halinde/,
  pubDate: Thu, 15 Jul 2021 13:37:49 +0300
 }*/
