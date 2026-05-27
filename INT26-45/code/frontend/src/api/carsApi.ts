export type Car = {
  company?: string | null;
  car_name?: string | null;
  engine?: string | null;

  cc?: number | null;
  battery_capacity?: number | null;

  min_hp?: number | null;
  max_hp?: number | null;

  total_speed?: number | null;
  zero_to_100_kmh?: number | null;

  min_price?: number | null;
  max_price?: number | null;

  fuel_types?: string[];

  seats?: number | null;
  torque?: string | null;
};

export type CarsResponse = {
  items: Car[];
  total: number;
  limit: number;
  offset: number;
};

export type AvgPriceByCompany = {
  company: string;
  avg_price: number;
  cars_count: number;
};

export type AvgPriceByCompanyResponse = {
  items: AvgPriceByCompany[];
};

const API_URL = import.meta.env.VITE_API_URL || "/api";

export async function getCars(
  limit: number = 50,
  offset: number = 0,
): Promise<CarsResponse> {
  const response = await fetch(`${API_URL}/cars?limit=${limit}&offset=${offset}`);

  if (!response.ok) {
    throw new Error("Failed to load cars");
  }

  return response.json();
}

export async function getAvgPriceByCompany(
  limit: number = 15,
): Promise<AvgPriceByCompanyResponse> {
  const response = await fetch(
    `${API_URL}/cars/stats/avg-price-by-company?limit=${limit}`,
  );

  if (!response.ok) {
    throw new Error("Failed to load chart data");
  }

  return response.json();
}

export async function reloadCars(): Promise<{ status: string; inserted: number }> {
  const response = await fetch(`${API_URL}/cars/reload`, {
    method: "POST",
  });

  if (!response.ok) {
    throw new Error("Failed to reload cars");
  }

  return response.json();
}