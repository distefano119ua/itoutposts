import {
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

import { AvgPriceByCompany } from "../api/carsApi";

type AvgPriceChartProps = {
  data: AvgPriceByCompany[];
};

function formatPrice(value: number): string {
  return `$${value.toLocaleString()}`;
}

export function AvgPriceChart({ data }: AvgPriceChartProps) {
  return (
    <section className="card">
      <div className="card-header">
        <div>
          <h2>Average price by company</h2>
          <p>Top brands by average car price</p>
        </div>
      </div>

      <div className="chart-wrapper">
        <ResponsiveContainer width="100%" height={360}>
          <BarChart data={data}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis
              dataKey="company"
              tick={{ fontSize: 12 }}
              interval={0}
              angle={-25}
              textAnchor="end"
              height={90}
            />
            <YAxis
              tickFormatter={(value) => `$${Number(value) / 1000}k`}
              tick={{ fontSize: 12 }}
            />
            <Tooltip
              formatter={(value) => formatPrice(Number(value))}
              labelFormatter={(label) => `Company: ${label}`}
            />
            <Bar dataKey="avg_price" radius={[8, 8, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </section>
  );
}