/** Button — ink pill CTA, secondary, quiet */
export interface ButtonProps {
  /** 'primary' (ink pill — ONE per screen) | 'secondary' | 'quiet' */
  variant?: 'primary' | 'secondary' | 'quiet';
  children: React.ReactNode;
  disabled?: boolean;
  fullWidth?: boolean;
  onClick?: () => void;
  style?: React.CSSProperties;
}
export declare function Button(props: ButtonProps): JSX.Element;
