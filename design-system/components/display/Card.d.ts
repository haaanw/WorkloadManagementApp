/** Card — stone planes: plain, emphasis, raised, debossed */
export interface CardProps {
  /** 'plain' | 'emphasis' | 'raised' (milled plate) | 'debossed' (pocket) */
  variant?: 'plain' | 'emphasis' | 'raised' | 'debossed';
  children: React.ReactNode;
  padding?: string;
  style?: React.CSSProperties;
}
export declare function Card(props: CardProps): JSX.Element;
