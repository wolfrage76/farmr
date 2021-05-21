import 'dart:core';
import 'dart:io' as io;
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

import 'package:chiabot/plot.dart';
import 'package:chiabot/log/filter.dart';
import 'package:chiabot/log/signagepoint.dart';

final log = Logger('Cache');

class Cache {
  List<String> ids = [];

  String binPath;

  List<Plot> _plots = []; //cached plots
  List<Plot> get plots => _plots;

  List<Filter> _filters = [];
  List<Filter> get filters => _filters;

  List<SignagePoint> _signagePoints = [];
  List<SignagePoint> get signagePoints => _signagePoints;

  final io.File _cache = io.File(".chiabot_cache.json");

  int parseUntil;

  Cache(String chiaConfigPath) {
    try {
      io.File _oldCache = io.File(chiaConfigPath + "chiabot_cache.json");
      if (!_cache.existsSync() && _oldCache.existsSync())
        _oldCache.copySync(_cache.absolute.path);
    } catch (Exception) {
      print("Failed to port old cache file");
    }
  }

  void init([bool parseLogs = false, int userNumber = 1]) {
    //populates id[] with random ids based on number of users provided by config
    ids = [];
    for (int i = 0; i < userNumber; i++) ids.add(Uuid().v4());

    //Tells log parser when it should stop parsing
    parseUntil =
        DateTime.now().subtract(Duration(days: 1)).millisecondsSinceEpoch;

    //Loads cache file
    if (!_cache.existsSync())
      save(); //creates cache file if doesnt exist
    else
      load(parseLogs); //chiabot_cache.json

    //generates new ids
    if (userNumber > ids.length) {
      int newIds = userNumber - ids.length;
      for (int i = 0; i < newIds; i++) ids.add(Uuid().v4());
    }

    save();
  }

  //saves cache file
  void save() {
    String contents = jsonEncode([
      {
        "ids": ids,
        "binPath": binPath,
        "plots": plots,
        "filters": filters,
        "signagePoints": signagePoints
      }
    ]);
    _cache.writeAsStringSync(contents);
  }

  void load(bool parseLogs) {
    _filters = [];
    _plots = [];
    _signagePoints = [];

    var contents = jsonDecode(_cache.readAsStringSync());

    //loads id from cache file //OLD
    if (contents[0]['id'] != null) {
      ids = [];
      ids.add(contents[0]['id']);
    }
    //loads ids from cache file //new
    if (contents[0]['ids'] != null) {
      ids = [];
      for (String id in contents[0]['ids']) ids.add(id);
    }

    //loads chia binary path from cache
    if (contents[0]['binPath'] != null) binPath = contents[0]['binPath'];

    try {
      if (parseLogs) {
        //loads plot list from cache file
        if (contents[0]['plots'] != null) {
          var plotsJson = contents[0]['plots'];

          for (var plotJson in plotsJson) _plots.add(Plot.fromJson(plotJson));
        }

        //loads filters list from cache file
        if (contents[0]['filters'] != null) {
          var filtersJson = contents[0]['filters'];

          for (var filterJson in filtersJson) {
            Filter filter = Filter.fromJson(filterJson, plots.length);
            if (filter.timestamp != null && filter.timestamp > parseUntil)
              _filters.add(filter);
          }
        }

        //loads subslots list from cache file
        if (contents[0]['signagePoints'] != null) {
          var signagePointsJson = contents[0]['signagePoints'];

          for (var signagePointJson in signagePointsJson) {
            SignagePoint signagePoint = SignagePoint.fromJson(signagePointJson);
            if (signagePoint.timestamp != null &&
                signagePoint.timestamp > parseUntil)
              _signagePoints.add(signagePoint);
          }
        }
      }
    } catch (Exception) {
      log.severe(
          "ERROR: Failed to load .chiabot_cache.json, please delete this file and restart client.");
    }
  }

  void savePlots(List<Plot> plots) {
    _plots = plots;
    save();
  }

  void saveFilters(List<Filter> filters) {
    _filters = filters;
    save();
  }

  void saveSignagePoints(List<SignagePoint> signagePoints) {
    _signagePoints = signagePoints;
    save();
  }
}
