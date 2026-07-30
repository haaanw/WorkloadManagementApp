export interface ReadoutWellProps {
  value: string | number;
  /** Mono unit annotation, e.g. 'MS' 'ACWR' */
  unit?: string;
  /** Fixed width — the well never resizes with digit count */
  width?: number;
  color?: string;
  size?: number;
}
export declare function ReadoutWell(props: ReadoutWellProps): JSX.Element;
