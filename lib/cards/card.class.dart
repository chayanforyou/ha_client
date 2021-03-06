part of '../main.dart';

class CardData {

  String type;
  List<EntityWrapper> entities = [];
  List conditions;
  bool showEmpty;
  List stateFilter;
  bool stateColor = true;

  EntityWrapper get entity => entities.isNotEmpty ? entities[0] : null;

  factory CardData.parse(rawData) {
    try {
      if (rawData['type'] == null) {
        rawData['type'] = CardType.ENTITIES;
      } else if (!(rawData['type'] is String)) {
        return CardData(null);
      }
      switch (rawData['type']) {
          case CardType.ENTITIES:
          case CardType.HISTORY_GRAPH:
          case CardType.PICTURE_GLANCE:
          case CardType.SENSOR:
          case CardType.ENTITY:
          case CardType.WEATHER_FORECAST:
          case CardType.PLANT_STATUS:
            if (rawData['entity'] != null) {
              rawData['entities'] = [rawData['entity']];
            }
            return EntitiesCardData(rawData);
            break;
          case CardType.ALARM_PANEL:
            return AlarmPanelCardData(rawData);
            break;
          case CardType.LIGHT:
            return LightCardData(rawData);
            break;
          case CardType.PICTURE_ELEMENTS:
            //TODO temporary solution 
            if (rawData.containsKey('camera_image')) {
              rawData['entity'] = rawData['camera_image'];
              return ButtonCardData(rawData);
            } else {
              return CardData(null);
            }
            break;
          case CardType.MAP:
            return MapCardData(rawData);
            break;
          case CardType.ENTITY_BUTTON:
          case CardType.BUTTON:
          case CardType.PICTURE_ENTITY:
            return ButtonCardData(rawData);
            break;
          case CardType.CONDITIONAL:
            return CardData.parse(rawData['card']);
            break;
          case CardType.ENTITY_FILTER:
            Map cardData = Map.from(rawData);
            cardData.remove('type');
            if (rawData.containsKey('card')) {
              cardData.addAll(rawData['card']);
            }
            cardData['type'] ??= CardType.ENTITIES;
            return CardData.parse(cardData);
            break;
          case CardType.GAUGE:
            return GaugeCardData(rawData);
            break;
          case CardType.GLANCE:
          case CardType.THERMOSTAT:
            if (rawData['entity'] != null) {
              rawData['entities'] = [rawData['entity']];
            }
            return GlanceCardData(rawData);
            break;
          case CardType.HORIZONTAL_STACK:
            return HorizontalStackCardData(rawData);
            break;
          case CardType.VERTICAL_STACK:
            return VerticalStackCardData(rawData);
            break;
          case CardType.MARKDOWN:
            return MarkdownCardData(rawData);
            break;
          case CardType.MEDIA_CONTROL:
            return MediaControlCardData(rawData);
            break;
          case CardType.BADGES:
            return BadgesData(rawData);
            break;
          default:
            if (rawData.containsKey('entity')) {
              rawData['entities'] = [rawData['entity']]; 
            }
            if (rawData.containsKey('entities') && rawData['entities'] is List) {
              return EntitiesCardData(rawData); 
            }
            return CardData(null);
        }
    } catch (error, stacktrace) {
      Logger.e('Error parsing card $rawData: $error', stacktrace: stacktrace);
      return ErrorCardData(rawData);
    }
  }

  CardData(rawData) {
    if (rawData != null && rawData is Map) {
      type = rawData['type'];
      conditions = rawData['conditions'] ?? [];
      showEmpty = rawData['show_empty'] ?? true;
      if (rawData.containsKey('state_filter') && rawData['state_filter'] is List) {
        stateFilter = rawData['state_filter'];
      } else {
        stateFilter = [];
      }
    } else {
      type = CardType.UNKNOWN;
      conditions = [];
      showEmpty = true;
      stateFilter = [];
    }
  }

  Widget buildCardWidget() {
    return UnsupportedCard(card: this);
  }

  List<EntityWrapper> getEntitiesToShow() {
    return entities.where((entityWrapper) {
      if (entityWrapper.entity.isHidden) {
        return false;
      }
      List currentStateFilter;
      if (entityWrapper.stateFilter != null && entityWrapper.stateFilter.isNotEmpty) {
        currentStateFilter = entityWrapper.stateFilter;
      } else {
        currentStateFilter = stateFilter;
      }
      bool showByFilter = currentStateFilter.isEmpty;
      for (var allowedState in currentStateFilter) {
        if (allowedState is String && allowedState == entityWrapper.entity.state) {
          showByFilter = true;
          break;
        } else if (allowedState is Map) {
          try {
            var tmpVal = allowedState['attribute'] != null ? entityWrapper.entity.getAttribute(allowedState['attribute']) : entityWrapper.entity.state;
            var valToCompareWith = allowedState['value'];
            var valToCompare;
            if (valToCompareWith is! String && tmpVal is String) {
              valToCompare = double.tryParse(tmpVal);
            } else {
              valToCompare = tmpVal;
            }
            if (valToCompare != null) {
              bool result;
              switch (allowedState['operator']) {
                case '<=': { result = valToCompare <= valToCompareWith;}
                break;
                
                case '<': { result = valToCompare < valToCompareWith;}
                break;

                case '>=': { result = valToCompare >= valToCompareWith;}
                break;

                case '>': { result = valToCompare > valToCompareWith;}
                break;

                case '!=': { result = valToCompare != valToCompareWith;}
                break;

                case 'regex': {
                  RegExp regExp = RegExp(valToCompareWith.toString());
                  result = regExp.hasMatch(valToCompare.toString());
                }
                break;

                default: {
                    result = valToCompare == valToCompareWith;
                  }
              }
              if (result) {
                showByFilter = true;
                break;
              }  
            }
          } catch (e, stacktrace) {
            Logger.e('Error filtering ${entityWrapper.entity.entityId} by $allowedState: $e', stacktrace: stacktrace);
          }
        }
      }
      return showByFilter;
    }).toList();
  }

}

class BadgesData extends CardData {

  String title;
  String icon;
  bool showHeaderToggle;

  @override
  Widget buildCardWidget() {
    return Badges(badges: this);
  }
  
  BadgesData(rawData) : super(rawData) {
    if (rawData['badges'] is List) {
      rawData['badges'].forEach((dynamic rawBadge) {
        if (rawBadge is String && HomeAssistant().entities.isExist(rawBadge)) {  
          entities.add(EntityWrapper(entity: HomeAssistant().entities.get(rawBadge)));
        } else if (rawBadge is Map && rawBadge.containsKey('entity') && HomeAssistant().entities.isExist(rawBadge['entity'])) {
          entities.add(
            EntityWrapper(
              entity: HomeAssistant().entities.get(rawBadge['entity']),
              overrideName: rawBadge["name"]?.toString(),
              overrideIcon: rawBadge["icon"],
            )
          );
        } else if (rawBadge is Map && rawBadge.containsKey('entities')) {
          _parseEntities(rawBadge);
        }
      });    
    }
  }

  void _parseEntities(rawData) {
    var rawEntities = rawData['entities'] ?? [];
    rawEntities.forEach((rawEntity) {
      if (rawEntity is String) {
        if (HomeAssistant().entities.isExist(rawEntity)) {
          entities.add(EntityWrapper(
            entity: HomeAssistant().entities.get(rawEntity),
            stateFilter: rawData['state_filter'] ?? [],
          ));
        }
      } else if (HomeAssistant().entities.isExist('${rawEntity['entity']}')) {
        Entity e = HomeAssistant().entities.get(rawEntity["entity"]);
        entities.add(
          EntityWrapper(
              entity: e,
              overrideName: rawEntity["name"]?.toString(),
              overrideIcon: rawEntity["icon"],
              stateFilter: rawEntity['state_filter'] ?? (rawData['state_filter'] ?? []),
              uiAction: EntityUIAction(rawEntityData: rawEntity)
          )
        );
      }
    });
  }

}

class EntitiesCardData extends CardData {

  String title;
  String icon;
  bool showHeaderToggle;

  @override
  Widget buildCardWidget() {
    return EntitiesCard(card: this);
  }
  
  EntitiesCardData(rawData) : super(rawData) {
    //Parsing card data
    title = rawData['title']?.toString();
    icon = rawData['icon'] is String ? rawData['icon'] : null;
    stateColor = rawData['state_color'] ?? false;
    showHeaderToggle = rawData['show_header_toggle'] ?? false;
    //Parsing entities
    var rawEntities = rawData['entities'] ?? [];
    rawEntities.forEach((rawEntity) {
      if (rawEntity is String) {
        if (HomeAssistant().entities.isExist(rawEntity)) {
          entities.add(EntityWrapper(entity: HomeAssistant().entities.get(rawEntity)));
        } else {
          entities.add(EntityWrapper(entity: Entity.missed(rawEntity)));
        }
      } else {
        if (rawEntity["type"] == "divider") {
          entities.add(EntityWrapper(entity: Entity.divider()));
        } else if (rawEntity["type"] == "section") {
          entities.add(EntityWrapper(entity: Entity.section(rawEntity["label"] ?? "")));
        } else if (rawEntity["type"] == "call-service") {
          Map uiActionData = {
            "tap_action": {
              "action": EntityUIAction.callService,
              "service": rawEntity["service"],
              "service_data": rawEntity["service_data"]
            },
            "hold_action": EntityUIAction.none
          };
          entities.add(
            EntityWrapper(
              entity: Entity.callService(
                icon: rawEntity["icon"],
                name: rawEntity["name"]?.toString(),
                service: rawEntity["service"],
                actionName: rawEntity["action_name"]
              ),
              stateColor: rawEntity["state_color"] ?? stateColor,
              uiAction: EntityUIAction(rawEntityData: uiActionData)
            )
          );
        } else if (rawEntity["type"] == "weblink") {
          Map uiActionData = {
            "tap_action": {
              "action": EntityUIAction.navigate,
              "service": rawEntity["url"]
            },
            "hold_action": EntityUIAction.none
          };
          entities.add(EntityWrapper(
              entity: Entity.weblink(
                  icon: rawEntity["icon"],
                  name: rawEntity["name"]?.toString(),
                  url: rawEntity["url"]
              ),
              stateColor: rawEntity["state_color"] ?? stateColor,
              uiAction: EntityUIAction(rawEntityData: uiActionData)
          )
          );
        } else if (HomeAssistant().entities.isExist(rawEntity["entity"])) {
          Entity e = HomeAssistant().entities.get(rawEntity["entity"]);
          entities.add(
            EntityWrapper(
                entity: e,
                stateColor: rawEntity["state_color"] ?? stateColor,
                overrideName: rawEntity["name"]?.toString(),
                overrideIcon: rawEntity["icon"],
                stateFilter: rawEntity['state_filter'] ?? [],
                uiAction: EntityUIAction(rawEntityData: rawEntity)
            )
          );
        } else {
          entities.add(EntityWrapper(entity: Entity.missed(rawEntity["entity"])));
        }
      }
    });
  }

}

class AlarmPanelCardData extends CardData {

  String name;
  List<dynamic> states;
  
  @override
  Widget buildCardWidget() {
    return AlarmPanelCard(card: this);
  }
  
  AlarmPanelCardData(rawData) : super(rawData) {
    //Parsing card data
    name = rawData['name']?.toString();
    states = rawData['states'];
    //Parsing entity
    var entitiId = rawData["entity"];
    if (entitiId != null && entitiId is String) {
      if (HomeAssistant().entities.isExist(entitiId)) {
        entities.add(EntityWrapper(
            entity: HomeAssistant().entities.get(entitiId),
            stateColor: true,
            overrideName: name
        ));
      } else {
        entities.add(EntityWrapper(entity: Entity.missed(entitiId)));
      }
    }
    
  }

}

class LightCardData extends CardData {

  String name;
  String icon;
  
  @override
  Widget buildCardWidget() {
    if (this.entity != null && this.entity.entity is LightEntity) {
      return LightCard(card: this);
    }
    return ErrorCard(
      errorText: 'Specify an entity from within the light domain.',
      showReportButton: false,
    );
  }
  
  LightCardData(rawData) : super(rawData) {
    //Parsing card data
    name = rawData['name']?.toString();
    icon = rawData['icon'] is String ? rawData['icon'] : null;
    //Parsing entity
    var entitiId = rawData["entity"];
    if (entitiId != null && entitiId is String) {
      if (HomeAssistant().entities.isExist(entitiId)) {
        entities.add(EntityWrapper(
            entity: HomeAssistant().entities.get(entitiId),
            overrideName: name,
            overrideIcon: icon,
            uiAction: EntityUIAction()..tapAction = EntityUIAction.toggle
        ));
      } else {
        entities.add(EntityWrapper(entity: Entity.missed(entitiId)));
      }
    } else {
      entities.add(EntityWrapper(entity: Entity.missed('$entitiId')));
    }
  }
}

class ButtonCardData extends CardData {

  String name;
  String icon;
  bool showName;
  bool showIcon;
  double iconHeightPx = 0;
  double iconHeightRem = 0;
  
  @override
  Widget buildCardWidget() {
    return EntityButtonCard(card: this);
  }
  
  ButtonCardData(rawData) : super(rawData) {
    //Parsing card data
    name = rawData['name']?.toString();
    icon = rawData['icon'] is String ? rawData['icon'] : null;
    showName = rawData['show_name'] ?? true;
    showIcon = rawData['show_icon'] ?? true;
    stateColor = rawData['state_color'] ?? true;
    var rawHeight = rawData['icon_height'];
    if (rawHeight != null && rawHeight is String) {
      if (rawHeight.contains('px')) {
        iconHeightPx = double.tryParse(rawHeight.replaceFirst('px', '')) ?? 0;
      } else if (rawHeight.contains('rem')) {
        iconHeightRem = double.tryParse(rawHeight.replaceFirst('rem', '')) ?? 0; 
      } else if (rawHeight.contains('em')) {
        iconHeightRem = double.tryParse(rawHeight.replaceFirst('em', '')) ?? 0;
      }
    }
    //Parsing entity
    var entitiId = rawData["entity"];
    if (entitiId != null && entitiId is String) {
      if (HomeAssistant().entities.isExist(entitiId)) {
        entities.add(EntityWrapper(
            entity: HomeAssistant().entities.get(entitiId),
            overrideName: name,
            overrideIcon: icon,
            stateColor: stateColor,
            uiAction: EntityUIAction(
              rawEntityData: rawData
            )
        ));
      } else {
        entities.add(EntityWrapper(entity: Entity.missed(entitiId)));
      }
    } else if (entitiId == null) {
      entities.add(
        EntityWrapper(
          entity: Entity.ghost(
            name,
            icon,
          ),
          stateColor: stateColor,
          uiAction: EntityUIAction(
            rawEntityData: rawData
          )
        )
      );
    }
  }
}

class GaugeCardData extends CardData {

  String name;
  String unit;
  double min;
  double max;
  Map severity;

  @override
  Widget buildCardWidget() {
    return GaugeCard(card: this);
  }
  
  GaugeCardData(rawData) : super(rawData) {
    //Parsing card data
    name = rawData['name']?.toString();
    unit = rawData['unit'];
    if (rawData['min'] is int) {
      min = rawData['min'].toDouble();  
    } else if (rawData['min'] is double) {
      min = rawData['min'];
    } else {
      min = 0;
    }
    if (rawData['max'] is int) {
      max = rawData['max'].toDouble();  
    } else if (rawData['max'] is double) {
      max = rawData['max'];
    } else {
      max = 100;
    }
    severity = rawData['severity'];
    //Parsing entity
    var entitiId = rawData["entity"] is List ? rawData["entity"][0] : rawData["entity"];
    if (entitiId != null && entitiId is String) {
      if (HomeAssistant().entities.isExist(entitiId)) {
        entities.add(EntityWrapper(
            entity: HomeAssistant().entities.get(entitiId),
            overrideName: name
        ));
      } else {
        entities.add(EntityWrapper(entity: Entity.missed(entitiId)));
      }
    } else {
      entities.add(EntityWrapper(entity: Entity.missed('$entitiId')));
    }
    
  }

}

class GlanceCardData extends CardData {

  String title;
  bool showName;
  bool showIcon;
  bool showState;
  bool stateColor;
  int columnsCount;

  @override
  Widget buildCardWidget() {
    return GlanceCard(card: this);
  }
  
  GlanceCardData(rawData) : super(rawData) {
    //Parsing card data
    title = rawData["title"]?.toString();
    showName = rawData['show_name'] ?? true;
    showIcon = rawData['show_icon'] ?? true;
    showState = rawData['show_state'] ?? true;
    stateColor = rawData['state_color'] ?? true;
    columnsCount = rawData['columns'] ?? 4;
    //Parsing entities
    var rawEntities = rawData["entities"] ?? [];
    rawEntities.forEach((rawEntity) {
      if (rawEntity is String) {
        if (HomeAssistant().entities.isExist(rawEntity)) {
          entities.add(EntityWrapper(entity: HomeAssistant().entities.get(rawEntity)));
        } else {
          entities.add(EntityWrapper(entity: Entity.missed(rawEntity)));
        }
      } else {
        if (HomeAssistant().entities.isExist(rawEntity["entity"])) {
          Entity e = HomeAssistant().entities.get(rawEntity["entity"]);
          entities.add(
            EntityWrapper(
                entity: e,
                stateColor: stateColor,
                overrideName: rawEntity["name"]?.toString(),
                overrideIcon: rawEntity["icon"],
                stateFilter: rawEntity['state_filter'] ?? [],
                uiAction: EntityUIAction(rawEntityData: rawEntity)
            )
          );
        } else {
          entities.add(EntityWrapper(entity: Entity.missed(rawEntity["entity"])));
        }
      }
    });
  }

}

class HorizontalStackCardData extends CardData {

  List<CardData> childCards;

  @override
  Widget buildCardWidget() {
    return HorizontalStackCard(card: this);
  }
  
  HorizontalStackCardData(rawData) : super(rawData) {
    if (rawData.containsKey('cards') && rawData['cards'] is List) {
      childCards = rawData['cards'].map<CardData>((childCard) {
        return CardData.parse(childCard);
      }).toList();
    } else {
      childCards = [];
    }
  }

}

class VerticalStackCardData extends CardData {

  List<CardData> childCards;

  @override
  Widget buildCardWidget() {
    return VerticalStackCard(card: this);
  }
  
  VerticalStackCardData(rawData) : super(rawData) {
    if (rawData.containsKey('cards') && rawData['cards'] is List) {
      childCards = rawData['cards'].map<CardData>((childCard) {
        return CardData.parse(childCard);
      }).toList();
    } else {
      childCards = [];
    }
  }

}

class MarkdownCardData extends CardData {

  String title;
  String content;

  @override
  Widget buildCardWidget() {
    return MarkdownCard(card: this);
  }
  
  MarkdownCardData(rawData) : super(rawData) {
    //Parsing card data
    title = rawData['title'];
    content = rawData['content'];
  }

}

class MapCardData extends CardData {

  String title;

  @override
  Widget buildCardWidget() {
    return MapCard(card: this);
  }

  MapCardData(rawData) : super(rawData) {
    //Parsing card data
    title = rawData['title'];
    List<dynamic> geoLocationSources = rawData['geo_location_sources'] ?? [];
    if (geoLocationSources.isNotEmpty) {
      //TODO add entities by source
    }
    var rawEntities = rawData["entities"] ?? [];
    rawEntities.forEach((rawEntity) {
      if (rawEntity is String) {
        if (HomeAssistant().entities.isExist(rawEntity)) {
          entities.add(EntityWrapper(entity: HomeAssistant().entities.get(rawEntity)));
        } else {
          entities.add(EntityWrapper(entity: Entity.missed(rawEntity)));
        }
      } else {
        if (HomeAssistant().entities.isExist(rawEntity["entity"])) {
          Entity e = HomeAssistant().entities.get(rawEntity["entity"]);
          entities.add(
              EntityWrapper(
                  entity: e,
                  stateColor: stateColor,
                  overrideName: rawEntity["name"]?.toString(),
                  overrideIcon: rawEntity["icon"],
                  stateFilter: rawEntity['state_filter'] ?? [],
                  uiAction: EntityUIAction(rawEntityData: rawEntity)
              )
          );
        } else {
          entities.add(EntityWrapper(entity: Entity.missed(rawEntity["entity"])));
        }
      }
    });
  }

}

class MediaControlCardData extends CardData {

  @override
  Widget buildCardWidget() {
    return MediaControlsCard(card: this);
  }

  MediaControlCardData(rawData) : super(rawData) {
    var entitiId = rawData["entity"];
    if (entitiId != null && entitiId is String) {
      if (HomeAssistant().entities.isExist(entitiId)) {
        entities.add(EntityWrapper(
            entity: HomeAssistant().entities.get(entitiId),
        ));
      } else {
        entities.add(EntityWrapper(entity: Entity.missed(entitiId)));
      }
    }
  }

}

class ErrorCardData extends CardData {

  String cardConfig;

  @override
  Widget buildCardWidget() {
    return ErrorCard(card: this);
  }

  ErrorCardData(rawData) : super(rawData) {
    cardConfig = '$rawData';
  }

}
