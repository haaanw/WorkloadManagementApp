export interface SparklineProps {
  data: number[];
  /** Metric identity hue token */
  hue?: string;
  /** Dashed reference line value */
  baseline?: number;
  width?: number;
  height?: number;
  startLabel?: string;
  endLabel?: string;
}
export declare function Sparkline(props: SparklineProps): JSX.Element;
