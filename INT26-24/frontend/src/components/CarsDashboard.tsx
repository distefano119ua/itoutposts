import { useEffect, useState } from "react";

import {
  AvgPriceByCompany,
  Car,
  getAvgPriceByCompany,
  getCars,
  reloadCars,
} from "../api/carsApi";
import { AvgPriceChart } from "./AvgPriceChart";
import { CarsTable } from "./CarsTable";

export function CarsDashboard() {
  const [cars, setCars] = useState<Car[]>([]);
  const [chartData, setChartData] = useState<AvgPriceByCompany[]>([]);

  const [total, setTotal] = useState<number>(0);
  const [limit] = useState<number>(50);
  const [offset, setOffset] = useState<number>(0);

  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);

  async function loadDashboardData(currentOffset: number): Promise<void> {
    setIsLoading(true);
    setError(null);

    try {
      const [carsResponse, chartResponse] = await Promise.all([
        getCars(limit, currentOffset),
        getAvgPriceByCompany(15),
      ]);

      setCars(carsResponse.items);
      setTotal(carsResponse.total);
      setChartData(chartResponse.items);
    } catch (error) {
      setError(error instanceof Error ? error.message : "Unknown error");
    } finally {
      setIsLoading(false);
    }
  }

  async function handleReload(): Promise<void> {
    setIsLoading(true);
    setError(null);

    try {
      await reloadCars();
      setOffset(0);
      await loadDashboardData(0);
    } catch (error) {
      setError(error instanceof Error ? error.message : "Unknown error");
      setIsLoading(false);
    }
  }

  useEffect(() => {
    loadDashboardData(offset);
  }, [offset]);

  const canGoPrev = offset > 0;
  const canGoNext = offset + limit < total;

  return (
    <main className="page">
      <header className="hero">
        <div>
          <p className="eyebrow">Cars analytics</p>
          <h1>Automotive dashboard</h1>
          <p className="subtitle">
            MongoDB data, FastAPI backend, React frontend.
          </p>
        </div>

        <button className="primary-button" onClick={handleReload} disabled={isLoading}>
          {isLoading ? "Loading..." : "Reload CSV"}
        </button>
      </header>

      {error && <div className="error-box">{error}</div>}

      <section className="stats-grid">
        <div className="metric-card">
          <span>Total cars</span>
          <strong>{total}</strong>
        </div>

        <div className="metric-card">
          <span>Page</span>
          <strong>{Math.floor(offset / limit) + 1}</strong>
        </div>

        <div className="metric-card">
          <span>Loaded rows</span>
          <strong>{cars.length}</strong>
        </div>
      </section>

      <AvgPriceChart data={chartData} />

      <CarsTable cars={cars} />

      <div className="pagination">
        <button
          disabled={!canGoPrev || isLoading}
          onClick={() => setOffset((currentOffset) => Math.max(currentOffset - limit, 0))}
        >
          Prev
        </button>

        <span>
          {offset + 1} - {Math.min(offset + limit, total)} of {total}
        </span>

        <button
          disabled={!canGoNext || isLoading}
          onClick={() => setOffset((currentOffset) => currentOffset + limit)}
        >
          Next
        </button>
      </div>
    </main>
  );
}