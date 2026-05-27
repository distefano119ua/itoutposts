from __future__ import annotations

import csv
import re
from pathlib import Path
from typing import Any

from config import settings
from motor.motor_asyncio import AsyncIOMotorClient


DB_NAME = settings.db_name
CARS_COLLECTION_NAME = "cars"

# CSV лежит рядом с этим файлом:
# app/cars/cars_data_set.csv
CSV_PATH = Path(__file__).resolve().parent / "cars_data_set.csv"


def clean_value(value: str | None) -> str | None:
    """
    Очищает строковое значение из CSV.
    """
    if value is None:
        return None

    value = value.strip()

    return value or None


def normalize_column_name(column: str) -> str:
    """
    Приводит обычные колонки CSV к нормальным именам полей MongoDB.

    Специальные колонки обрабатываются отдельно:
    - CC/Battery Capacity -> cc, battery_capacity
    - HorsePower -> min_hp, max_hp
    - Total Speed -> total_speed
    - Performance(0 - 100 )KM/H -> zero_to_100_kmh
    - Cars Prices -> min_price, max_price
    - Fuel Types -> fuel_types
    """
    clean_column = column.strip()

    mapping: dict[str, str] = {
        "Company Names": "company",
        "Cars Names": "car_name",
        "Engines": "engine",
        "Seats": "seats",
        "Torque": "torque",
    }

    return mapping.get(
        clean_column,
        clean_column.lower().replace(" ", "_"),
    )


def parse_number_with_commas(value: str | None) -> int | float | None:
    """
    Преобразует строковое число в int/float.

    Examples:
        "3990" -> 3990
        "1,200" -> 1200
        "3,982" -> 3982
        "7.9" -> 7.9
    """
    cleaned_value = clean_value(value)

    if cleaned_value is None:
        return None

    normalized_value = cleaned_value.replace(",", "")

    if "." in normalized_value:
        return float(normalized_value)

    return int(normalized_value)


def parse_cc_battery_capacity(value: str | None) -> dict[str, int | float | None]:
    """
    Разделяет 'CC/Battery Capacity' на:
    - cc
    - battery_capacity

    Examples:
        "3990 cc" -> {"cc": 3990, "battery_capacity": None}
        "1,200 cc" -> {"cc": 1200, "battery_capacity": None}
        "3,982 cc" -> {"cc": 3982, "battery_capacity": None}
        "100 kWh" -> {"cc": None, "battery_capacity": 100}
        "3990 cc / 7.9 kWh" -> {"cc": 3990, "battery_capacity": 7.9}
    """
    cleaned_value = clean_value(value)

    if cleaned_value is None:
        return {
            "cc": None,
            "battery_capacity": None,
        }

    lower_value = cleaned_value.lower()

    cc_match = re.search(r"(\d[\d,]*(?:\.\d+)?)\s*cc\b", lower_value)
    battery_match = re.search(r"(\d[\d,]*(?:\.\d+)?)\s*kwh\b", lower_value)

    return {
        "cc": parse_number_with_commas(cc_match.group(1)) if cc_match else None,
        "battery_capacity": (
            parse_number_with_commas(battery_match.group(1))
            if battery_match
            else None
        ),
    }


def parse_horse_power(value: str | None) -> dict[str, int | None]:
    """
    Разделяет 'HorsePower' на:
    - min_hp
    - max_hp

    Examples:
        "563 hp" -> {"min_hp": 563, "max_hp": 563}
        "70-85 hp" -> {"min_hp": 70, "max_hp": 85}
        "70 - 85 hp" -> {"min_hp": 70, "max_hp": 85}
    """
    cleaned_value = clean_value(value)

    if cleaned_value is None:
        return {
            "min_hp": None,
            "max_hp": None,
        }

    numbers = re.findall(r"\d+", cleaned_value)

    if not numbers:
        return {
            "min_hp": None,
            "max_hp": None,
        }

    if len(numbers) == 1:
        hp = int(numbers[0])

        return {
            "min_hp": hp,
            "max_hp": hp,
        }

    return {
        "min_hp": int(numbers[0]),
        "max_hp": int(numbers[1]),
    }


def parse_total_speed(value: str | None) -> dict[str, int | None]:
    """
    Преобразует 'Total Speed' в число.

    Examples:
        "340 km/h" -> {"total_speed": 340}
        "250 km/h" -> {"total_speed": 250}
    """
    cleaned_value = clean_value(value)

    if cleaned_value is None:
        return {"total_speed": None}

    match = re.search(r"\d+", cleaned_value)

    return {
        "total_speed": int(match.group(0)) if match else None,
    }


def parse_zero_to_100_kmh(value: str | None) -> dict[str, float | None]:
    """
    Преобразует 'Performance(0 - 100 )KM/H' в число.

    Examples:
        "2.5 sec" -> {"zero_to_100_kmh": 2.5}
        "5.3 sec" -> {"zero_to_100_kmh": 5.3}
    """
    cleaned_value = clean_value(value)

    if cleaned_value is None:
        return {"zero_to_100_kmh": None}

    match = re.search(r"\d+(?:\.\d+)?", cleaned_value)

    return {
        "zero_to_100_kmh": float(match.group(0)) if match else None,
    }


def parse_price(value: str | None) -> dict[str, int | None]:
    """
    Разделяет 'Cars Prices' на:
    - min_price
    - max_price

    Examples:
        "$460,000 " -> {"min_price": 460000, "max_price": 460000}
        "$12,000-$15,000" -> {"min_price": 12000, "max_price": 15000}
        "$1,100,000" -> {"min_price": 1100000, "max_price": 1100000}
    """
    cleaned_value = clean_value(value)

    if cleaned_value is None:
        return {
            "min_price": None,
            "max_price": None,
        }

    normalized_value = (
        cleaned_value
        .replace("$", "")
        .replace(",", "")
        .replace(" ", "")
    )

    numbers = re.findall(r"\d+", normalized_value)

    if not numbers:
        return {
            "min_price": None,
            "max_price": None,
        }

    if len(numbers) == 1:
        price = int(numbers[0])

        return {
            "min_price": price,
            "max_price": price,
        }

    return {
        "min_price": int(numbers[0]),
        "max_price": int(numbers[1]),
    }


def parse_fuel_types(value: str | None) -> dict[str, list[str]]:
    """
    Разделяет 'Fuel Types' на список.

    Examples:
        "Petrol" -> {"fuel_types": ["Petrol"]}
        "Petrol/Diesel" -> {"fuel_types": ["Petrol", "Diesel"]}
        "plug in hyrbrid" -> {"fuel_types": ["plug in hyrbrid"]}
    """
    cleaned_value = clean_value(value)

    if cleaned_value is None:
        return {"fuel_types": []}

    fuel_types = [
        fuel_type.strip()
        for fuel_type in cleaned_value.split("/")
        if fuel_type.strip()
    ]

    return {"fuel_types": fuel_types}


def parse_seats(value: str | None) -> int | None:
    """
    Преобразует 'Seats' в число.
    """
    cleaned_value = clean_value(value)

    if cleaned_value is None:
        return None

    match = re.search(r"\d+", cleaned_value)

    return int(match.group(0)) if match else None


def read_cars_csv() -> list[dict[str, Any]]:
    """
    Читает CSV-файл и преобразует строки в документы для MongoDB.
    """
    if not CSV_PATH.exists():
        raise FileNotFoundError(f"CSV-файл не найден: {CSV_PATH}")

    documents: list[dict[str, Any]] = []

    with CSV_PATH.open("r", encoding="utf-8-sig", newline="") as file:
        reader = csv.DictReader(file, skipinitialspace=True)

        for row in reader:
            document: dict[str, Any] = {}

            for raw_key, raw_value in row.items():
                if raw_key is None:
                    continue

                clean_key = raw_key.strip()

                if clean_key == "CC/Battery Capacity":
                    document.update(parse_cc_battery_capacity(raw_value))
                    continue

                if clean_key == "HorsePower":
                    document.update(parse_horse_power(raw_value))
                    continue

                if clean_key == "Total Speed":
                    document.update(parse_total_speed(raw_value))
                    continue

                if clean_key == "Performance(0 - 100 )KM/H":
                    document.update(parse_zero_to_100_kmh(raw_value))
                    continue

                if clean_key == "Cars Prices":
                    document.update(parse_price(raw_value))
                    continue

                if clean_key == "Fuel Types":
                    document.update(parse_fuel_types(raw_value))
                    continue

                if clean_key == "Seats":
                    document["seats"] = parse_seats(raw_value)
                    continue

                key = normalize_column_name(clean_key)
                value = clean_value(raw_value)

                document[key] = value

            if document:
                documents.append(document)

    return documents


async def load_cars_csv_to_mongodb(
    mongo_client: AsyncIOMotorClient,
) -> dict[str, Any]:
    """
    Читает CSV и полностью перезаписывает коллекцию cars.
    """
    documents = read_cars_csv()

    db = mongo_client[DB_NAME]
    collection = db[CARS_COLLECTION_NAME]

    await collection.delete_many({})

    if documents:
        await collection.insert_many(documents)

    return {
        "status": "ok",
        "inserted": len(documents),
    }


async def get_cars_from_mongodb(
    mongo_client: AsyncIOMotorClient,
    limit: int = 50,
    offset: int = 0,
) -> dict[str, Any]:
    """
    Возвращает автомобили из MongoDB для frontend.
    """
    db = mongo_client[DB_NAME]
    collection = db[CARS_COLLECTION_NAME]

    cursor = collection.find({}, {"_id": 0}).skip(offset).limit(limit)

    items = await cursor.to_list(length=limit)
    total = await collection.count_documents({})

    return {
        "items": items,
        "total": total,
        "limit": limit,
        "offset": offset,
    }


async def get_avg_price_by_company(
    mongo_client: AsyncIOMotorClient,
    limit: int = 15,
) -> list[dict[str, Any]]:
    """
    Возвращает среднюю цену автомобилей по брендам.

    Использует MongoDB aggregation.
    Берём среднее между min_price и max_price,
    потом группируем по company.
    """
    db = mongo_client[DB_NAME]
    collection = db[CARS_COLLECTION_NAME]

    pipeline = [
        {
            "$match": {
                "company": {"$ne": None},
                "min_price": {"$ne": None},
                "max_price": {"$ne": None},
            }
        },
        {
            "$addFields": {
                "avg_car_price": {
                    "$avg": ["$min_price", "$max_price"]
                }
            }
        },
        {
            "$group": {
                "_id": "$company",
                "avg_price": {"$avg": "$avg_car_price"},
                "cars_count": {"$sum": 1},
            }
        },
        {
            "$sort": {
                "avg_price": -1
            }
        },
        {
            "$limit": limit
        },
        {
            "$project": {
                "_id": 0,
                "company": "$_id",
                "avg_price": {"$round": ["$avg_price", 0]},
                "cars_count": 1,
            }
        },
    ]

    cursor = collection.aggregate(pipeline)

    return await cursor.to_list(length=limit)

