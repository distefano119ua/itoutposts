import { Car } from "../api/carsApi";

type CarsTableProps = {
  cars: Car[];
};

function formatValue(value: string | number | null | undefined): string {
  if (value === null || value === undefined || value === "") {
    return "-";
  }

  return String(value);
}

function formatPrice(minPrice?: number | null, maxPrice?: number | null): string {
  if (minPrice == null && maxPrice == null) {
    return "-";
  }

  if (minPrice === maxPrice) {
    return `$${minPrice?.toLocaleString()}`;
  }

  return `$${minPrice?.toLocaleString()} - $${maxPrice?.toLocaleString()}`;
}

function formatHp(minHp?: number | null, maxHp?: number | null): string {
  if (minHp == null && maxHp == null) {
    return "-";
  }

  if (minHp === maxHp) {
    return `${minHp} hp`;
  }

  return `${minHp} - ${maxHp} hp`;
}

export function CarsTable({ cars }: CarsTableProps) {
  return (
    <section className="card">
      <div className="card-header">
        <div>
          <h2>Cars dataset</h2>
          <p>Imported from MongoDB</p>
        </div>
      </div>

      <div className="table-wrapper">
        <table>
          <thead>
            <tr>
              <th>Company</th>
              <th>Car</th>
              <th>Engine</th>
              <th>CC</th>
              <th>Battery</th>
              <th>HP</th>
              <th>Speed</th>
              <th>0-100</th>
              <th>Price</th>
              <th>Fuel</th>
              <th>Seats</th>
              <th>Torque</th>
            </tr>
          </thead>

          <tbody>
            {cars.map((car, index) => (
              <tr key={`${car.company}-${car.car_name}-${index}`}>
                <td>{formatValue(car.company)}</td>
                <td>{formatValue(car.car_name)}</td>
                <td>{formatValue(car.engine)}</td>
                <td>{formatValue(car.cc)}</td>
                <td>{formatValue(car.battery_capacity)}</td>
                <td>{formatHp(car.min_hp, car.max_hp)}</td>
                <td>{car.total_speed ? `${car.total_speed} km/h` : "-"}</td>
                <td>{car.zero_to_100_kmh ? `${car.zero_to_100_kmh} sec` : "-"}</td>
                <td>{formatPrice(car.min_price, car.max_price)}</td>
                <td>{car.fuel_types?.length ? car.fuel_types.join(", ") : "-"}</td>
                <td>{formatValue(car.seats)}</td>
                <td>{formatValue(car.torque)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}