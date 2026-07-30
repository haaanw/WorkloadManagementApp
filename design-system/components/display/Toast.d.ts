export interface ToastProps {
  message: string;
  /** Mono glyph, default '✓' */
  glyph?: string;
  visible?: boolean;
}
export declare function Toast(props: ToastProps): JSX.Element;
