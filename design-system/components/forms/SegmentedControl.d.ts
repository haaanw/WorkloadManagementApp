export interface SegmentedControlProps {
  options: string[];
  value: string;
  onChange?: (next: string) => void;
}
export declare function SegmentedControl(props: SegmentedControlProps): JSX.Element;
