export interface SparkBarProps {
  data: number[];
  /** Hue of the current (last) bar */
  hue?: string;
  /** Faint placeholder bars after the data (days remaining) */
  trailing?: number;
}
export declare function SparkBar(props: SparkBarProps): JSX.Element;
