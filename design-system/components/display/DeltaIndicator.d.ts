export interface DeltaIndicatorProps {
  /** Signed change; 0 renders '=' */
  delta: number;
  /** Whether an increase is favorable (false for e.g. resting HR) */
  goodIsUp?: boolean;
  /** |delta| at which the glyph fills (▲ vs △) */
  threshold?: number;
}
export declare function DeltaIndicator(props: DeltaIndicatorProps): JSX.Element;
