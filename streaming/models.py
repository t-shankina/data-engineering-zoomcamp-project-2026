import dataclasses
from datetime import datetime, timezone
import json

server = 'localhost:9092'
topic = 'ais_data'


@dataclasses.dataclass
class PositionReport:    
    message_id: int # Identifies the ITU-R M.1371 message type (1, 2, or 3)
    user_id: str # MMSI (Maritime Mobile Service Identity) — unique 9-digit vessel identifier
    longitude: float # Longitude in degrees (East/West)
    latitude: float # Latitude in degrees (North/South)
    position_accuracy: bool # True = High (< 10m, DGPS), False = Low (> 10m, standard GPS)
    raim: bool # True = RAIM in use, False = RAIM not in use
    timestamp: int # UTC second when position was generated. 60 = not available, 61 = manual, 62 = dead reckoning, 63 = inoperative
    cog: float # Course Over Ground. Degrees relative to true north. Range: 0–359.9°. 360 = not available
    sog: float # Speed Over Ground in knots. Range: 0–102.2 knots. 102.3 = not available
    true_heading: int # Heading of the bow in degrees true north. Range: 0–359°. 511 = not available
    rate_of_turn: int # Rate of turn in degrees/min. +127 = turning right, -127 = turning left, −128 = not available
    navigational_status: int # Vessel operational status: 0=under way, 1=at anchor, 2=not under command, 3=restricted, etc.
    special_manoeuvre_indicator: int # 0 = not available, 1 = not engaged, 2 = engaged in special maneuver


def get_postion_report_from_message(message):
    message_dict = message['Message']['PositionReport']

    return PositionReport(
        message_id=int(message_dict['MessageID']),
        user_id=str(message_dict['UserID']),
        longitude=float(message_dict['Longitude']),
        latitude=float(message_dict['Latitude']),
        position_accuracy=bool(message_dict['PositionAccuracy']),
        raim=bool(message_dict['Raim']),
        timestamp=int(message_dict['Timestamp']),
        cog=float(message_dict['Cog']),
        sog=float(message_dict['Sog']),
        true_heading=int(message_dict['TrueHeading']),
        rate_of_turn=int(message_dict['RateOfTurn']),
        navigational_status=int(message_dict['NavigationalStatus']),
        special_manoeuvre_indicator=int(message_dict['SpecialManoeuvreIndicator']),
    )


def position_report_serializer(position_report):
    position_report_dict = dataclasses.asdict(position_report)
    position_report_dict['produced_at'] = datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S.%f')
    json_str = json.dumps(position_report_dict)
    return json_str.encode('utf-8')


# def position_report_deserializer(data):
#     json_str = data.decode('utf-8')
#     position_report_dict = json.loads(json_str)
#     return PositionReport(**position_report_dict)


# def position_report_deserializer(data):
#     json_str = data.decode('utf-8')
#     position_report_dict = json.loads(json_str)
    
#     valid_fields = {f.name for f in dataclasses.fields(PositionReport)}
#     filtered_dict = {k: v for k, v in position_report_dict.items() if k in valid_fields}
    
#     return PositionReport(**filtered_dict)
