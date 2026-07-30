export interface TextFieldProps {
  label?: string;
  value: string;
  onChange?: (next: string) => void;
  placeholder?: string;
  /** Error message — border and text go zone-danger */
  error?: string;
  type?: string;
}
export declare function TextField(props: TextFieldProps): JSX.Element;
