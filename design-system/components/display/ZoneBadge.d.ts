export interface ZoneBadgeProps {
  zone?: 'optimal' | 'caution' | 'danger' | 'low';
  /** The text label IS the information; color is supplementary */
  label: string;
  /** zh-Hans: wider padding, no caps/tracking */
  cjk?: boolean;
}
export declare function ZoneBadge(props: ZoneBadgeProps): JSX.Element;
