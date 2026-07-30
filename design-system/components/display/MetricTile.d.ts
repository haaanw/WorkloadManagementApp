export interface MetricTileProps {
  title: string;
  value: string | number;
  subtitle?: string;
  /** Value color — a metric hue or ink */
  color?: string;
}
export declare function MetricTile(props: MetricTileProps): JSX.Element;
