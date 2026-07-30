export interface IconButtonProps {
  /** Unicode glyph, e.g. '×' '＋' '›' — no icon fonts */
  glyph: string;
  /** Accessible label (required) */
  label: string;
  selected?: boolean;
  onClick?: () => void;
}
export declare function IconButton(props: IconButtonProps): JSX.Element;
