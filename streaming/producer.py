import asyncio
from datetime import datetime, timezone
import json
import logging
import os

from aiokafka import AIOKafkaProducer
from dotenv import load_dotenv
import websockets

from models import (
    get_postion_report_from_message,
    position_report_serializer,
    server,
    topic,
)

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)


async def connect_ais_stream():
    producer = AIOKafkaProducer(
        bootstrap_servers=[server],
        value_serializer=position_report_serializer,
    )
    
    await producer.start()
    logger.info("Producer successfully connected to broker at %s", server)


    try:
        async with websockets.connect("wss://stream.aisstream.io/v0/stream") as websocket:
            subscribe_message = {
                "APIKey": os.environ["AISSTREAMIO_API_KEY"],
                "BoundingBoxes": [[[40.87, 28.69], [41.11, 29.14]]],
                "FilterMessageTypes": ["PositionReport"]
            }
            logger.info("Connected to AIS stream")

            subscribe_message_json = json.dumps(subscribe_message)
            await websocket.send(subscribe_message_json)
            logger.info("Subscribed to position reports in the specified bounding box")

            logger.info("Sending events (Ctrl+C to stop)...")
            async for message_json in websocket:
                message = json.loads(message_json)
                message_type = message["MessageType"]

                ais_message = message['Message']['PositionReport']
                print(f"[{datetime.now(timezone.utc)}] ShipId: {ais_message['UserID']} Latitude: {ais_message['Latitude']} Longitude: {ais_message['Longitude']}")

                if message_type == "PositionReport":
                    position_report = get_postion_report_from_message(message)

                    await producer.send(topic, value=position_report)
                    
    except KeyboardInterrupt:
        logger.warning("Interrupt received, initiating graceful shutdown...")

    except Exception as e:
        logger.error("Unexpected error occurred: %s", e)

    finally:
        logger.info("Flushing remaining messages to topic %s...", topic)
        await producer.flush()
        logger.info("All buffered messages have been successfully flushed")

        await producer.stop()
        logger.info("Producer stopped, connection to broker closed")


if __name__ == "__main__":
    asyncio.run(connect_ais_stream())
