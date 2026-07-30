export interface StepperProps {
  value: number;
  onChange?: (next: number) => void;
  min?: number;
  max?: number;
  step?: number;
  /** Unit annotation inside the well, e.g. 'KG' 'REPS' */
  unit?: string;
  wellWidth?: number;
}
export declare function Stepper(props: StepperProps): JSX.Element;
