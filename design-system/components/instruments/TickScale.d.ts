export interface TickScaleProps {
  value: number;
  min?: number;
  max?: number;
  /** [lo, hi] optimal band, tinted zone-optimal @12% */
  zone?: [number, number];
  /** Ghost mark (e.g. yesterday) */
  ghost?: number;
  width?: string | number;
  /** Needle color — accent (default) or a metric hue */
  hue?: string;
}
export declare function TickScale(props: TickScaleProps): JSX.Element;
