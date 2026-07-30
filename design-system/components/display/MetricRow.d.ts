export interface MetricRowProps {
  label: string;
  value: string | number;
  unit?: string;
  /** Signed number; 0 renders '=' */
  delta?: number;
  /** Metric identity hue token, e.g. 'var(--metric-recovery)' */
  hue?: string;
  onClick?: () => void;
  /** Suppress the bottom hairline on the final row */
  last?: boolean;
}
export declare function MetricRow(props: MetricRowProps): JSX.Element;
