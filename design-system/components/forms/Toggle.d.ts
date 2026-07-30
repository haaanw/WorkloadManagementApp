export interface ToggleProps {
  checked: boolean;
  onChange?: (next: boolean) => void;
  label?: string;
}
export declare function Toggle(props: ToggleProps): JSX.Element;
