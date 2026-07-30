export interface KeyRowProps {
  /** Equal-weight decision cells; at most one role:'cta' (ink-filled) */
  keys: { title: string; role?: 'standard' | 'cta'; onClick?: () => void }[];
}
export declare function KeyRow(props: KeyRowProps): JSX.Element;
