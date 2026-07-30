export interface SufficiencyRingProps {
  /** 0–100 */
  pct: number;
  size?: number;
  /** Mono label below, e.g. 'BASELINE' */
  label?: string;
}
export declare function SufficiencyRing(props: SufficiencyRingProps): JSX.Element;
